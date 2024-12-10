clear; clc; close all;

%% Load Data
im1 = dicomread('../Data/20240830/series/IM-0002-0066.dcm');
im2 = dicomread('../Data/20240910/series/IM-0001-0443.dcm');

figure;
imshowpair(im1, im2, 'falsecolor');
title('Image Pair')

%% Load Info
im1_info = dicominfo('../Data/20240830/series/IM-0002-0066.dcm');
im2_info = dicominfo('../Data/20240910/series/IM-0001-0443.dcm');

%% Rescale Image

%% Threshold
im1_double = double(im1);
im2_double = double(im2);

threshold = 1324;
imBW1 = im1_double > threshold;
imBW2 = im2_double > threshold;

imBW1_double = double(imBW1) * 10;
imBW2_double = double(imBW2) * 10;

figure;
subplot(1, 2, 1);
imshow(imBW1_double, []);
title('Thresholded Image 1');

subplot(1, 2, 2);
imshow(imBW2_double, []);
title('Thresholded Image 2');

%% Register
[optimizer, metric] = imregconfig('monomodal');
regIm_rigid = imregister(imBW2_double, imBW1_double, 'rigid', optimizer, metric);
regIm_similarity = imregister(imBW2_double, imBW1_double, 'similarity', optimizer, metric);
regIm_affine = imregister(imBW2_double, imBW1_double, 'affine', optimizer, metric);

figure;
subplot(1, 3, 1);
imshowpair(imBW1, regIm_rigid, 'falsecolor');
title('Registered Image - Rigid');

subplot(1, 3, 2);
imshowpair(imBW1, regIm_similarity, 'falsecolor');
title('Registered Image - Similarity');

subplot(1, 3, 3);
imshowpair(imBW1, regIm_affine, 'falsecolor');
title('Registered Image - Affine');

%% Test Different Registration Settings
clc
[optimizer, metric] = imregconfig('monomodal');
disp(optimizer);
disp(metric);

optimizer.GradientMagnitudeTolerance = 1e-4;
optimizer.MinimumStepLength = 1e-5;
optimizer.MaximumStepLength = 6.25e-2;
optimizer.MaximumIterations = 100;
optimizer.RelaxationFactor = 5e-1;

regIm = imregister(imBW2_double, imBW1_double, 'similarity', optimizer, metric, 'DisplayOptimization', true);

figure;
imshowpair(imBW1, regIm, 'falsecolor');

%% Get and Apply Transform
clc;
[optimizer, metric] = imregconfig('monomodal');
disp(optimizer);
optimizer.MaximumStepLength = 5e-2;
optimizer.MaximumIterations = 100;

tform = imregtform(imBW2_double, imBW1_double, 'similarity', optimizer, metric, 'DisplayOptimization', true,'PyramidLevels', 3);
regIm_tform = imwarp(im2_double, tform, 'OutputView', imref2d(size(im2)));

figure;
imshowpair(im1, regIm_tform, 'falsecolor');
title('Registered Grayscale Image');

%% Load Directories for Each Image Set
imSet1 = dir('../Data/20240830/series/*');
imSet2 = dir('../Data/20240910/series/*');

%% Apply Transform to Each Image
outputFolder = '../Data/20240830_20240910';
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

for i = 1:length(imSet1)
    fileName1 = imSet1.name;
    fileName2 = imSet2.name;

    lastDigits1 = extractAfter(fileName1, strlength(fileName1) - 3);
    lastDigits2 = extractAfter(fileName2, strlength(fileName2) - 3);

    if ~strcmp(lastDigits1, lastDigits2)
        fprintf('Skipping index %d: Mismatch in filenames (%s vs %s)\n', i, fileName1, fileName2);
        continue;
    end

    if i == 384
        fprintf('Skipping index 384\n');
        continue
    end

    im1 = dicomread(fullfile(imSet1(i).folder, imSet1(i).name));
    im2 = dicomread(fullfile(imSet2(i).folder, imSet2(i).name));

    imReg2 = imwarp(im2, tform, 'OutputView', imref2d(size(im1)));
    
    newFileName = sprintf('IM-0001-%03d.dcm', i);
    outputFilePath = fullfile(outputFolder, newFileName);

    dicomwrite(uint16(imReg2), outputFilePath);
end

%% Check
imCheck = dicomread('../Data/20240830_20240910/IM-0001-0200.dcm');

figure;
imshow(imCheckBW, []);
title('Check Registered Image');