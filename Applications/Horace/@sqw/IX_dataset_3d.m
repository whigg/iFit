% Create IX_dataset_3d object
%
%   >> w = IX_dataset_3d (x,y,z)
%   >> w = IX_dataset_3d (x,y,z,signal)
%   >> w = IX_dataset_3d (x,y,z,signal,error)
%   >> w = IX_dataset_3d (x,y,z,signal,error,title,x_axis,y_axis,z_axis,s_axis)
%   >> w = IX_dataset_3d (x,y,z,signal,error,title,x_axis,y_axis,z_axis,s_axis,x_distribution,y_distribution,z_distribution)
%   >> w = IX_dataset_3d (title, signal, error, s_axis, x, x_axis, x_distribution,...
%                                          y, y_axis, y_distribution, z, z-axis, z_distribution)
%
%  Creates an IX_dataset_3d object with the following elements:
%
% 	title				char/cellstr	Title of dataset for plotting purposes (character array or cellstr)
% 	signal              double  		Signal (3D array)
% 	error				        		Standard error (3D array)
% 	s_axis				IX_axis			Signal axis object containing caption and units codes
%                   (or char/cellstr    Can also just give caption; multiline input in the form of a
%                                      cell array or a character array)
% 	x					double      	Values of bin boundaries (if histogram data)
% 						                Values of data point positions (if point data)
% 	x_axis				IX_axis			x-axis object containing caption and units codes
%                   (or char/cellstr    Can also just give caption; multiline input in the form of a
%                                      cell array or a character array)
% 	x_distribution      logical         Distribution data flag (true is a distribution; false otherwise)
%
%   y                   double          -|
%   y_axis              IX_axis          |- same as above but for y-axis
%   y_distribution      logical         -|
%
%   z                   double          -|
%   z_axis              IX_axis          |- same as above but for z-axis
%   z_distribution      logical         -|
%