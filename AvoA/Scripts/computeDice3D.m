function diceScore = computeDice3D(fixed, moving)
    if ~islogical(fixed)
        fixed = imbinarize(fixed);
    end
    if ~islogical(moving)
        moving = imbinarize(moving);
    end

    intersection = sum(fixed(:) & moving(:));
    totalVoxels = sum(fixed(:)) + sum(moving(:));

    if totalVoxels == 0
        diceScore = 1;
    else
        diceScore = (2 * intersection) / totalVoxels;
    end
end
