function saveMIPLapseVideo(MIPImages, outputFile, frameRate)
    if nargin < 3
        frameRate = 10;
    end

    video = VideoWriter(outputFile, 'MPEG-4');
    video.FrameRate = frameRate;

    open(video);

    fig = figure('Name', 'Recording MIP Time-Lapse', 'NumberTitle', 'off', 'Visible', 'off');
    ax = axes('Parent', fig);

    numFrames = size(MIPImages, 3);
    for i = 1:numFrames
        imshow(MIPImages(:, :, i), [], 'Parent', ax);
        colormap(ax, gray);
        axis(ax, 'image');
        title(ax, ['Frame: ', num2str(i)], 'FontSize', 14);

        frame = getframe(fig);
        writeVideo(video, frame);
    end

    close(video);

    close(fig);

    fprintf('Video saved to %s\n', outputFile);
end
