function repoRoot = getRepoRoot()

repoRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));

end
