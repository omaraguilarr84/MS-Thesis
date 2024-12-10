clear; clc; close all;

% Set paths to the DICOM directories
dicomFolder1 = '../Data/20240830/series';
dicomFolder2 = '../Data/20240910/series';

% Load DICOM series for scan 1
scan1Files = dir(fullfile(dicomFolder1, '*.dcm'));
scan1 = [];
for k = 1:length(scan1Files)
    slice = dicomread(fullfile(scan1Files(k).folder, scan1Files(k).name));
    scan1(:, :, k) = slice;
end

% Load DICOM series for scan 2
scan2Files = dir(fullfile(dicomFolder2, '*.dcm'));
scan2 = [];
for k = 1:length(scan2Files)
    slice = dicomread(fullfile(scan2Files(k).folder, scan2Files(k).name));
    scan2(:, :, k) = slice;
end

% Optional: Convert to double for registration compatibility
scan1 = double(scan1);
scan2 = double(scan2);

% Visualize middle slice of Scan 1
imshow(scan1(:, :, round(size(scan1, 3) / 2)), []);

% Visualize middle slice of Scan 2
imshow(scan2(:, :, round(size(scan2, 3) / 2)), []);

%% Register
% Set up the fixed and moving images
fixedVolume = scan1; % Choose one as fixed
movingVolume = scan2; % The other as moving

% Register the moving volume to the fixed volume
[optimizer, metric] = imregconfig('monomodal');
registeredVolume = imregister(movingVolume, fixedVolume, 'similarity', optimizer, metric);

% Display results
figure;
subplot(1, 2, 1);
imshow(fixedVolume(:, :, round(size(fixedVolume, 3) / 2)), []);
title('Fixed Volume Middle Slice');
subplot(1, 2, 2);
imshow(registeredVolume(:, :, round(size(registeredVolume, 3) / 2)), []);
title('Registered Volume Middle Slice');
