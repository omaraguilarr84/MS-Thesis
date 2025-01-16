function [im, info] = loadDicom3D(imFolderPath)
    dicomFolder = imFolderPath;
    
    files = dir(fullfile(dicomFolder, '*.dcm'));
    
    scan = [];
    for i = 1:length(files)
        slice = dicomread(fullfile(files(i).folder, files(i).name));
        scan(:, :, i) = slice;

         % tmp_info = dicominfo(fullfile(files(i).folder, files(i).name));
         % sliceLoc(i) = tmp_info.SliceLocation;
    end

     % dSL = diff(sliceLoc);
     % SliceThickness = abs(mean(dSL));

    info = dicominfo(fullfile(files(1).folder, files(1).name));
    im = info.RescaleSlope * scan + info.RescaleIntercept;
    % info.SliceThickness = SliceThickness;
    % im = scan;
end