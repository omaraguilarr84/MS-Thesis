clear; clc; close all;

dataFolder = '../AvoData/';

subfolders = dir(dataFolder);
subfolders = subfolders([subfolders.isdir]);
subfolders = subfolders(~ismember({subfolders.name}, {'.', '..'}));

dates = {subfolders.name};
dates = sort(dates);

fixedDate = dates{1};
fixedPath = fullfile(dataFolder, fixedDate, 'series');
[fixedImage, fInfo] = loadDicom3D(fixedPath);

threshold_shell = 500;
fixedImageBW = double(fixedImage > threshold_shell);

shellFixed = find(any(any(fixedImageBW > 0, 1), 2));

% If image z-dimension is backwards, reverse the image
if shellFixed(1) < 300
    fixedImage = fixedImage(:, :, end:-1:1);
end

fixedMIP = MIPxyz(fixedImage, false);
MIPImages = fixedMIP.tile;

for i = 2:length(dates)
    fprintf('Creating MIP %d of %d...\n', i-1, length(dates)-1);

    movingDate = dates{i};
    movingPath = fullfile(dataFolder, movingDate, 'series');

    if exist(movingPath, 'dir')
        [movingImage, mInfo] = loadDicom3D(movingPath);

        movingImageBW = double(movingImage > threshold_shell);
        
        shellMoving = find(any(any(movingImageBW > 0, 1), 2));
    
        if shellMoving(1) < 300
            movingImage = movingImage(:, :, end:-1:1);
        end
    
        movingMIP = MIPxyz(movingImage, false);
        MIPImages = cat(3, MIPImages, movingMIP.tile);
    end
end

MIPxyzLapse(MIPImages);

%% Create Video
saveMIPLapseVideo(MIPImages, '../MIP_Videos/Initial_MIPs.mp4', 3);