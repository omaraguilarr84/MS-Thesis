clear; clc; close all;

fixedFolder = '../Data/20240910/series/';
movingFolder = '../Data/20241007/series/';

[fixedImage, fInfo] = loadDicom3D(fixedFolder);

[optimizer, metric] = imregconfig('monomodal');

optimizer.GradientMagnitudeTolerance = 1e-6;
optimizer.MinimumStepLength = 1e-4;
optimizer.MaximumStepLength = 6.25e-2;
optimizer.MaximumIterations = 100;
optimizer.RelaxationFactor = 0.7;

regIm = regIms3D(movingFolder, fixedFolder, 100, optimizer, metric);

%%
[fixedImage, fInfo] = loadDicom3D(fixedFolder);
[movingImage, mInfo] = loadDicom3D(movingFolder);

%%
interactiveRegVis(double(movingImage > 300) * 10, double(fixedImage > 300) * 10, 'z');

%%
regVideo(regIm, double(fixedImage > 100) * 10, 'z');