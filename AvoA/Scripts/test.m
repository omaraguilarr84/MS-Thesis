clear; clc; close all;

dicomFolder = '../Data/20240910/series';
dicomFolder1 = '../AvoData/20240830/series';
warning('off', 'MATLAB:DELETE:Permission');
[im, info] = loadDicom3D(dicomFolder);
[im0, info0] = loadDicom3D(dicomFolder1);

im1=MIPxyz(im, false);

%%
windowLevel = [800 1300];
figure(10);
imagesc(im1.tile,[800 1300]);colormap gray;axis equal

%%
im2 = MIPxyzWindowed(im, windowLevel, true);
MIPImages = im2.tile;

%%

movingMIP = MIPxyzWindowed(im0, windowLevel, true);
%%
MIPImages = cat(3, MIPImages, movingMIP.tile);
MIPxyzLapse(MIPImages);