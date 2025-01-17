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

windowLevel = [-200 300];
fixedMIP = MIPxyzWindowed(fixedImage, windowLevel, false);
MIPImages = fixedMIP.tile;

fovSizes = {'small'};
frameDates = {fixedDate};

for i = 2:length(dates)
    fprintf('Creating MIP %d of %d...\n', i-1, length(dates)-1);

    currentFolder = fullfile(dataFolder, dates{i});

    movingDate = dates{i};
    series = fullfile(dataFolder, movingDate, 'series');
    seriesFull = fullfile(dataFolder, movingDate, 'seriesFull');

    subDirs = dir(currentFolder);
    subDirs = subDirs([subDirs.isdir]);
    subDirs = subDirs(~ismember({subDirs.name}, {'.', '..'}));

    for j = 1:length(subDirs)
        seriesFolder = fullfile(currentFolder, subDirs(j).name);
        
        if strcmp(seriesFolder, series)
            movingPath = series;
            fov = 'small';
        elseif strcmp(seriesFolder, seriesFull)
            movingPath = seriesFull;
            fov = 'large';
        else
            continue;
        end

        [movingImage, mInfo] = loadDicom3D(movingPath);

        movingImageBW = double(movingImage > threshold_shell);
        
        shellMoving = find(any(any(movingImageBW > 0, 1), 2));
    
        if shellMoving(1) < 300
            movingImage = movingImage(:, :, end:-1:1);
        end
    
        movingMIP = MIPxyzWindowed(movingImage, windowLevel, false);
        MIPImages = cat(3, MIPImages, movingMIP.tile);

        fovSizes{end + 1} = fov;
        frameDates{end + 1} = dates{i};
    end
end

MIPxyzLapse(MIPImages, frameDates, fovSizes);

%% Create Video
saveMIPLapseVideo(MIPImages, '../MIP_Videos/Initial_MIPs_All.mp4', 3);