function [mr] = euclidian(recordings)
%EUCLIDIAN Calculates the Euclidian bending moment from Mx and My 
%   Assumes mx is in column 3 and my is in column 4

mr = cell(length(recordings),1);

for i=1:length(recordings) 
    mr{i} = sqrt(recordings{i}(:,3).^2 + recordings{i}(:,4).^2);
end

end