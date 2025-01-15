clear; clc; close all;

dataFolder = '../2024_amirlab_Avo/';
outputFolder = '../AvoData/';

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

subfolders = dir(dataFolder);
subfolders = subfolders([subfolders.isdir]);
subfolders = subfolders(~ismember({subfolders.name}, {'.', '..'}));

dates = {subfolders.name};
dates = sort(dates);

for i = 1:length(dates)
    fprintf('Sorting folder %d of %d...\n', i, length(dates));

    if i < length(dates) && startsWith(dates{i+1}, dates{i})
        continue;
    end

    srcFolder = fullfile(dataFolder, dates{i});
    
    contents = dir(srcFolder);
    isDir = [contents.isdir];
    subDirs = contents(isDir);
    subDirs = subDirs(~ismember({subDirs.name}, {'.', '..'}));
    
    if isempty(subDirs)
        dicomFiles = dir(fullfile(srcFolder, '*.dcm'));
        if isempty(dicomFiles)
            disp(['No DICOM files found in ', dates{i}]);
            continue;
        end
        
        for j = 1:length(dicomFiles)
            [~, fileName, ext] = fileparts(dicomFiles(j).name);
            
            % Extract series tag (e.g., '0028') from the filename pattern 'IM-0028-0249'
            parts = split(fileName, '-');
            if length(parts) < 3
                warning(['File name does not follow the expected pattern: ', fileName]);
                continue;
            end
            seriesTag = parts{2};
            
            % Create a folder for the series tag if it doesn't exist
            seriesFolder = fullfile(srcFolder, seriesTag);
            if ~exist(seriesFolder, 'dir')
                mkdir(seriesFolder);
            end
            
            % Move the DICOM file to the corresponding folder
            srcFile = fullfile(srcFolder, dicomFiles(j).name);
            destFile = fullfile(seriesFolder, dicomFiles(j).name);
            movefile(srcFile, destFile);
        end
    end

    contents = dir(srcFolder);
    isDir = [contents.isdir];
    subDirs = contents(isDir);
    subDirs = subDirs(~ismember({subDirs.name}, {'.', '..'}));

    for k = 1:length(subDirs)
        currentSubfolder = fullfile(srcFolder, subDirs(k).name);

        dicomFiles = dir(fullfile(currentSubfolder, '*.dcm'));
        numFiles = numel(dicomFiles);

        if numFiles == 512
            destFolder = fullfile(outputFolder, dates{i});

            if ~exist(destFolder, 'dir')
                mkdir(destFolder);
            end

            movefile(currentSubfolder, destFolder);
        end
    end
end

%%
outputFolder = '../AvoData/';

subfolders = dir(outputFolder);
subfolders = subfolders([subfolders.isdir]);
subfolders = subfolders(~ismember({subfolders.name}, {'.', '..'}));

dates = {subfolders.name};
dates = sort(dates);

for i = 1:length(dates)
    fprintf('Renaming folder %d of %d...\n', i, length(dates));

    j = 1;
    srcFolder = fullfile(outputFolder, dates{i});

    contents = dir(srcFolder);
    isDir = [contents.isdir];
    subDirs = contents(isDir);
    subDirs = subDirs(~ismember({subDirs.name}, {'.', '..'}));

    if numel(subDirs) > 1
        j = numel(subDirs);
    end

    copyFolder = fullfile(srcFolder, subDirs(j).name);
    copyfile(copyFolder, fullfile(srcFolder, 'series'));
end
