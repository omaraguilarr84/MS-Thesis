clear; clc; close all;

%% Load Info and Image
dicomFolder1 = '../Data/20240910/series/';
dicomFolder2 = '../Data/20241007/series/';

[im1, info1] = loadDicom3D(dicomFolder1);
[im2, info2] = loadDicom3D(dicomFolder2);

%% Threshold & Downsample Images
disp('Thresholding images...');
threshold = 500;
imBW1 = im1 > threshold;
imBW2 = im2 > threshold;

scale = 10;

imBW1_double = double(imBW1) * scale;
imBW2_double = double(imBW2) * scale;

step = 1;
imBW1_down = imBW1_double(1:step:end, 1:step:end, 1:step:end);
imBW2_down = imBW2_double(1:step:end, 1:step:end, 1:step:end);

im1_down = im1(1:step:end, 1:step:end, 1:step:end);
im2_down = im2(1:step:end, 1:step:end, 1:step:end);

%%
interactiveRegVis(imBW1_down, imBW2_down, 'z');

seashell1 = 440;
seashell2 = 440;
shell = find(any(any(imBW1_down > 0, 1), 2));

% figure;
% subplot(2, 2, 1);
% imshow(imBW1(:, :, seashell1), []);
% title('Fixed Binary Mask (Full Size)');
% 
% subplot(2, 2, 2);
% imshow(imBW2(:, :, seashell2), []);
% title('Moving Binary Mask (Full Size)');
% 
% subplot(2, 2, 3);
% imshow(imBW1_down(:, :, seashell1/2), []);
% title('Fixed Binary Mask (Downsampled)');
% 
% subplot(2, 2, 4);
% imshow(imBW2_down(:, :, seashell2/2), []);
% title('Moving Binary Mask (Downsampled)')

%% Get References
ref1 = createRef(info1, imBW1_down, step);
ref2 = createRef(info2, imBW2_down, step);

%% Get Transform
disp('Computing transform...');
[optimizer, metric] = imregconfig('monomodal');

optimizer.GradientMagnitudeTolerance = 5e-5;
optimizer.MinimumStepLength = 1.6e-5;
optimizer.MaximumStepLength = 1e-3;
optimizer.MaximumIterations = 300;
optimizer.RelaxationFactor = 0.3;
pyramidLevels = 3;

clc;
delete('optimization_log.txt');
diary('optimization_log.txt');

tform = imregtform(imBW2_down, ref2_down, imBW1_down, ref1_down, ...
    'affine', optimizer, metric, 'DisplayOptimization', true, 'PyramidLevels', pyramidLevels);

diary off;

%% Plot Optimization
plotOptimizationResults('optimization_log.txt');

%% Register Image
registeredBW2 = imwarp(imBW2_down, ref2_down, tform, 'OutputView', ref1_down);

overlap = 2 * nnz(imBW1_down & registeredBW2) / (nnz(imBW1_down) + nnz(registeredBW2));
disp(['Dice Coefficient: ', num2str(overlap)]);

mseValue = immse(imBW1_down, registeredBW2);
disp('MSE Value:');
disp(mseValue);

% %% Visualize Result
% figure;
% imshowpair(imBW1_down(:, :, seashell1/2), ...
%            registeredBW2(:, :, seashell2/2), ...
%            'falsecolor');
% title('Overlay of Fixed and Registered Binary Masks');
% 
% %% Visualize Results Separately
% figure;
% subplot(1, 2, 1);
% imshow(imBW1_down(:, :, seashell1/2), []);
% title('Fixed Image');
% 
% subplot(1, 2, 2);
% imshow(registeredBW2(:, :, seashell2/2), [])
% title('Moving Image');

%% Interactive Visualization of Z
interactiveRegVis(registeredBW2, imBW1_down, 'z');

%% Write Video of Interactive Visualization
regVideo(registeredBW2, imBW1_down, 'y');

%%
regIm = imwarp(im2_rescaled, ref2_down, tform, 'OutputView', ref1_down);
interactiveRegVis(regIm, im1_rescaled, 'z');
