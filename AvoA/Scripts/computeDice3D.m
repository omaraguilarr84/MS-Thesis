function diceScore = computeDice3D(fixed, moving)
    % Ensure both inputs are binary volumes (logical)
    if ~islogical(fixed)
        fixed = imbinarize(fixed);
    end
    if ~islogical(moving)
        moving = imbinarize(moving);
    end

    % Compute intersection and total voxel counts
    intersection = sum(fixed(:) & moving(:));
    totalVoxels = sum(fixed(:)) + sum(moving(:));

    % Handle division by zero
    if totalVoxels == 0
        diceScore = 1; % Perfect match for empty volumes
    else
        diceScore = (2 * intersection) / totalVoxels;
    end
end
