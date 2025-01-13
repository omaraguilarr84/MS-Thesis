function MIPxyzLapse(MIPImages)
    numFrames = size(MIPImages, 3);

    fig = figure('Name', 'MIP Time-Lapse Viewer', 'NumberTitle', 'off', 'Position', [100, 100, 800, 600]);
    ax = axes('Parent', fig);

    hImage = imshow(MIPImages(:, :, 1), [], 'Parent', ax);
    colormap(ax, gray);
    axis(ax, 'image');

    hTitle = title(ax, 'MIP Time Lapse, Index: 1', 'FontSize', 14);

    slider = uicontrol('Style', 'slider', ...
        'Min', 1, 'Max', numFrames, 'Value', 1, ...
        'SliderStep', [1/(numFrames-1), 10/(numFrames-1)], ...
        'Units', 'normalized', ...
        'Position', [0.2, 0.02, 0.6, 0.05], ...
        'Callback', @(src, event) updateImageWithLabelAndTitle(src, hImage, MIPImages, hTitle));

    label = uicontrol('Style', 'text', ...
        'Units', 'normalized', ...
        'Position', [0.8, 0.02, 0.1, 0.05], ...
        'String', 'Frame: 1', ...
        'FontSize', 10);

    slider.Callback = @(src, event) updateImageWithLabelAndTitle(src, hImage, MIPImages, hTitle, label);
end

function updateImage(slider, hImage, MIPImages)
    frameIdx = round(slider.Value);

    hImage.CData = MIPImages(:, :, frameIdx);
end

function updateImageWithLabelAndTitle(slider, hImage, MIPImages, hTitle, label)
    updateImage(slider, hImage, MIPImages);

    frameIdx = round(slider.Value);

    hTitle.String = ['MIP Time Lapse, Index: ', num2str(frameIdx)];

    if nargin > 4
        label.String = ['Frame: ', num2str(frameIdx)];
    end
end
