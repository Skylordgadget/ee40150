function [recordings] = loadrecordings(filenames)
%LOADRECORDINGS Loads the contents of drill recordings into matrices
%   Assumes the input is a cell array of type {N,1}
%   Uses the readmatrix function to read text files
recordings = cell(length(filenames),1);

for i=1:length(filenames)
    recordings{i,1} = readmatrix(filenames(i), 'CommentStyle', '#');
end

end