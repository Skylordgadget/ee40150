function [filenames] = readdir(dir_path, extension)
%READDIRECTORY Reads and returns all the filenames in a specified directory
%   
files = dir([dir_path '/*.' extension]);

filenames = strings([length(files),1]);

for i=1:length(files)
    filenames(i) = [dir_path '/' files(i).name];
end

end