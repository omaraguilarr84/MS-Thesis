function hd = computeHausdorffDistance(binaryImage1, binaryImage2)
    % Compute the Hausdorff distance between two binary images.
    %
    % Inputs:
    %   binaryImage1 - First binary image (logical or binary matrix)
    %   binaryImage2 - Second binary image (logical or binary matrix)
    %
    % Output:
    %   hd - Hausdorff distance
    
    % Ensure the images are binary
    binaryImage1 = logical(binaryImage1);
    binaryImage2 = logical(binaryImage2);
    
    % Compute the Euclidean distance transform
    D1 = bwdist(binaryImage1);
    D2 = bwdist(binaryImage2);
    
    % Find the maximum distance from one image to the other
    hd1 = max(D2(binaryImage1)); % Max distance from binaryImage1 to binaryImage2
    hd2 = max(D1(binaryImage2)); % Max distance from binaryImage2 to binaryImage1
    
    % Hausdorff distance is the maximum of the two
    hd = max(hd1, hd2);
end
