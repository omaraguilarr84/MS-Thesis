function MIPxyzLapse(MIPImages, dates, fovSizes)
    % Function to display a time-lapse viewer for MIP images
    % Inputs:
    %   MIPImages - 3D array of MIP images
    %   dates - Cell array of strings representing dates
    %   fovSizes - Cell array of strings representing FOV size descriptors (e.g., 'small', 'large')

    numFrames = size(MIPImages, 3);

    fig = figure('Name', 'MIP Time-Lapse Viewer', 'NumberTitle', 'off', 'Position', [100, 100, 800, 100], 'Resize', 'off');
    ax = axes('Parent', fig);

    hImage = imshow(MIPImages(:, :, 1), [], 'Parent', ax);
    colormap(ax, gray);
    axis(ax, 'image');

    % Display the date and FOV size in the title
    hTitle = title(ax, sprintf('Date: %s, FOV: %s', ...
        dates{1}, fovSizes{1}), ...
        'FontSize', 12, 'Interpreter', 'none');

    slider = uicontrol('Style', 'slider', ...
        'Min', 1, 'Max', numFrames, 'Value', 1, ...
        'SliderStep', [1/(numFrames-1), 10/(numFrames-1)], ...
        'Units', 'normalized', ...
        'Position', [0.2, 0.02, 0.6, 0.05], ...
        'Callback', @(src, event) updateImageWithLabelAndTitle(src, hImage, MIPImages, hTitle, dates, fovSizes));

    label = uicontrol('Style', 'text', ...
        'Units', 'normalized', ...
        'Position', [0.8, 0.02, 0.1, 0.05], ...
        'String', 'Frame: 1', ...
        'FontSize', 10);

    slider.Callback = @(src, event) updateImageWithLabelAndTitle(src, hImage, MIPImages, hTitle, dates, fovSizes, label);
end

function updateImage(slider, hImage, MIPImages)
    % Update the displayed image based on the slider value
    frameIdx = round(slider.Value);
    hImage.CData = MIPImages(:, :, frameIdx);
end

function updateImageWithLabelAndTitle(slider, hImage, MIPImages, hTitle, dates, fovSizes, label)
    % Update the image, title, and label dynamically
    updateImage(slider, hImage, MIPImages);

    frameIdx = round(slider.Value);

    % Update the title with the date and FOV size
    hTitle.String = sprintf('Date: %s, FOV: %s', ...
        dates{frameIdx}, fovSizes{frameIdx});

    if nargin > 6
        label.String = sprintf('Frame: %d', frameIdx);
    end
end