clear; clc; close all;

%% Load Info and Image
dicomFolder1 = '../Data/20240830/series/';
dicomFolder2 = '../Data/20240910/series/';

files1 = dir(fullfile(dicomFolder1, '*.dcm'));
files2 = dir(fullfile(dicomFolder2, '*.dcm'));

scan1 = [];
for i = 1:length(files1)
    slice = dicomread(fullfile(files1(i).folder, files1(i).name));
    scan1(:, :, i) = slice;
end

scan2 = [];
for i = 1:length(files2)
    slice = dicomread(fullfile(files2(i).folder, files2(i).name));
    scan2(:, :, i) = slice;
end

info1 = dicominfo(fullfile(files1(1).folder, files1(1).name));
info2 = dicominfo(fullfile(files2(1).folder, files2(1).name));

%% Rescale Images
im1_rescaled = info1.RescaleSlope * scan1 + info1.RescaleIntercept;
im2_rescaled = info2.RescaleSlope * scan2 + info2.RescaleIntercept;

%% Threshold & Downsample Images
threshold = 100;
imBW1 = im1_rescaled > threshold;
imBW2 = im2_rescaled > threshold;

scale = 1e-3;

imBW1_double = double(imBW1) * scale;
imBW2_double = double(imBW2) * scale;

step = 2;
imBW1_down = imBW1_double(1:step:end, 1:step:end, 1:step:end);
imBW2_down = imBW2_double(1:step:end, 1:step:end, 1:step:end);

im1_rescaled_down = im1_rescaled(1:step:end, 1:step:end, 1:step:end);
im2_rescaled_down = im2_rescaled(1:step:end, 1:step:end, 1:step:end);

figure;
subplot(2, 2, 1);
imshow(imBW1(:, :, 66), []);
title('Fixed Binary Mask (Full Size)');

subplot(2, 2, 2);
imshow(imBW2(:, :, 443), []);
title('Moving Binary Mask (Full Size)');

subplot(2, 2, 3);
imshow(imBW1_down(:, :, 33), []);
title('Fixed Binary Mask (Downsampled)');

subplot(2, 2, 4);
imshow(imBW2_down(:, :, 222), []);
title('Moving Binary Mask (Downsampled)')

%% Get References
ref1 = imref3d(size(im1_rescaled), ...
               info1.PixelSpacing(1), ... % X spacing
               info1.PixelSpacing(2), ... % Y spacing
               info1.SliceThickness);     % Z spacing

ref2 = imref3d(size(im2_rescaled), ...
               info2.PixelSpacing(1), ...
               info2.PixelSpacing(2), ...
               info2.SliceThickness);

adjustedPixelSpacing1 = info1.PixelSpacing * step;
adjustedPixelSpacing2 = info2.PixelSpacing * step;

adjustedSliceThickness1 = info1.SliceThickness * step;
adjustedSliceThickness2 = info2.SliceThickness * step;

ref1_down = imref3d(size(imBW1_down), ...
                    adjustedPixelSpacing1(1), ... % X spacing
                    adjustedPixelSpacing1(2), ... % Y spacing
                    adjustedSliceThickness1);     % Z spacing

ref2_down = imref3d(size(imBW2_down), ...
                    adjustedPixelSpacing2(1), ...
                    adjustedPixelSpacing2(2), ...
                    adjustedSliceThickness2);

%% Get Transform
[optimizer, metric] = imregconfig('monomodal');

optimizer.GradientMagnitudeTolerance = 1e-4;
optimizer.MinimumStepLength = 1e-5;
optimizer.MaximumStepLength = 5e-2;
optimizer.MaximumIterations = 100;
optimizer.RelaxationFactor = 5e-1;

clc;
delete('optimization_log.txt');
diary('optimization_log.txt');

tform = imregtform(imBW2_down, ref2_down, imBW1_down, ref1_down, ...
    'similarity', optimizer, metric, 'DisplayOptimization', true);

diary off;

%% Plot Optimization
plotOptimizationResults('optimization_log.txt')

%% Register Image
registeredBW2 = imwarp(imBW2_down, ref2_down, tform, 'OutputView', ref1_down);

%% Visualize Result
figure;
imshowpair(imBW1_down(:, :, 33), ...
           registeredBW2(:, :, 222), ...
           'falsecolor');
title('Overlay of Fixed and Registered Binary Masks');

%% Visualize Results Separately
figure;
subplot(1, 2, 1);
imshow(imBW1(:, :, 66), []);
title('Fixed Image');

subplot(1, 2, 2);
imshow(registeredBW2(:, :, 222), [])
title('Moving Image');
