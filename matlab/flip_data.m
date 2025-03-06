function [flipped_data] = flip_data(data)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here

flipped_data = cell(length(data),1);
for i=1:length(data)
    flipped_data{i} = data{i}';
end

end