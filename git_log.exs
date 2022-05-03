read_head = fn ->
  head_path = Path.join([".git", "HEAD"])

  <<"ref: " :: binary, ref_path :: binary>> = File.read!(head_path)

  [".git", ref_path]
  |> Path.join()
  |> String.trim()
  |> File.read!()
  |> String.trim()
end

inflate = fn binary ->
  z = :zlib.open()
  :zlib.inflateInit(z)
  [uncompressed] = :zlib.inflate(z, binary)
  :zlib.close(z)

  uncompressed
end

read_file_from_hash = fn <<dir :: binary-size(2), filename :: binary>> ->
  path = Path.join([".git", "objects", dir, filename])

  path
  |> File.read!()
  |> inflate.()
end

get_message = fn content ->
  content
  |> String.split("\n\n")
  |> Enum.at(1)
  |> String.trim()
end

get_date = fn content ->
  content
  |> String.split("\n")
  |> Enum.filter(fn "author" <> _rest -> true; _ -> false end)
  |> List.first()
  |> String.reverse()
  |> (fn <<_offset :: binary-size(6), date :: binary-size(10), _ :: binary>> -> String.reverse(date) end).()
end

get_short_hash = fn <<commit :: binary-size(7), _ :: binary>> ->
  commit
end

get_parents = fn content ->
  content
  |> String.split("\n", trim: true)
  |> Enum.filter(fn "parent" <> _rest -> true; _ -> false end)
  |> Enum.map(fn "parent" <> commit -> commit end)
  |> Enum.map(&String.trim/1)
end

get_commits = fn [], _fun -> [];
                 commit_hashes, fun ->
  for commit_hash <- commit_hashes do
    parents =
      commit_hash
      |> read_file_from_hash.()
      |> get_parents.()
      |> fun.(fun)

    [commit_hash | parents]
  end
  |> List.flatten()
end

load_commits = fn commits ->
  for commit <- commits do
    {commit, read_file_from_hash.(commit)}
  end
end

extract_commit_data = fn commits ->
  for {commit, content} <- commits do
    {
      get_short_hash.(commit),
      get_date.(content),
      get_message.(content)
    }
  end
end

sort = fn commits ->
  commits
  |> Enum.sort_by(fn {_, date, _} -> date end)
  |> Enum.reverse()
end

pretty_print = fn commits ->
  for {short_hash, _, msg} <- commits do
    "#{short_hash} #{msg}"
  end
  |> Enum.join("\n")
end

_test = fn ->
  read_head.()
  |> List.wrap()
  |> get_commits.(get_commits)
  |> Enum.uniq()
  |> load_commits.()
  |> extract_commit_data.()
  |> sort.()
  |> pretty_print.()
  |> IO.puts()
end.()
