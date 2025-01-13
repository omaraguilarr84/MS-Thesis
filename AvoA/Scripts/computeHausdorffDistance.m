function hd = computeHausdorffDistance(binaryImage1, binaryImage2)
    % Ensure inputs are logical
    binaryImage1 = logical(binaryImage1);
    binaryImage2 = logical(binaryImage2);
    
    % Get coordinates of foreground (true) pixels in both images
    [z1, y1, x1] = ind2sub(size(binaryImage1), find(binaryImage1)); % Points in binaryImage1
    [z2, y2, x2] = ind2sub(size(binaryImage2), find(binaryImage2)); % Points in binaryImage2
    
    % Combine coordinates into point sets
    points1 = [x1, y1, z1];
    points2 = [x2, y2, z2];
    
    % Compute pairwise distances between points1 and points2
    distances = pdist2(points1, points2);
    
    % Compute directed Hausdorff distances
    d1 = max(min(distances, [], 2)); % Max of min distances from points1 to points2
    d2 = max(min(distances, [], 1)); % Max of min distances from points2 to points1
    
    % Exact Hausdorff distance is the maximum of the two directed distances
    hd = max(d1, d2);
end
