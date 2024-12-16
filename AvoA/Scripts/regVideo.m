function regVideo(registeredImage, fixedImage, dim)
    if dim == 'z'
        videoFilename = 'registration_visualization_z.mp4';
        v = VideoWriter(videoFilename, 'MPEG-4');
        v.FrameRate = 10;
        open(v);
        
        figure;
        hAx = axes('Position', [0.1, 0.2, 0.8, 0.7]);
        hImage = imshowpair(fixedImage(:, :, 1), ...
                            registeredImage(:, :, 1), ...
                            'falsecolor');
        title(['Slice along Z-axis at index 1']);
        
        for sliceIdx = 1:size(fixedImage, 3)
            imshowpair(fixedImage(:, :, sliceIdx), ...
                       registeredImage(:, :, sliceIdx), ...
                       'falsecolor', 'Parent', hAx);
            title(hAx, ['Slice along Z-axis at index ', num2str(sliceIdx)]);
            
            frame = getframe(gcf);
            
            writeVideo(v, frame);
        end
        
        close(v);
        
        disp(['Video saved as ', videoFilename]);
    elseif dim == 'x'
        videoFilename = 'registration_visualization_x.mp4';
        v = VideoWriter(videoFilename, 'MPEG-4');
        v.FrameRate = 10;
        open(v);
        
        figure;
        hAx = axes('Position', [0.1, 0.2, 0.8, 0.7]);
        hImage = imshowpair(squeeze(fixedImage(1, :, :)), ...
                            squeeze(registeredImage(1, :, :)), ...
                            'falsecolor');
        title(['Slice along X-axis at index 1']);
        
        for sliceIdx = 1:size(fixedImage, 1)
            imshowpair(squeeze(fixedImage(sliceIdx, :, :)), ...
                       squeeze(registeredImage(sliceIdx, :, :)), ...
                       'falsecolor', 'Parent', hAx);
            title(hAx, ['Slice along X-axis at index ', num2str(sliceIdx)]);
            
            frame = getframe(gcf);
            
            writeVideo(v, frame);
        end
        
        close(v);
        
        disp(['Video saved as ', videoFilename]);
    elseif dim == 'y'
        videoFilename = 'registration_visualization_y.mp4';
        v = VideoWriter(videoFilename, 'MPEG-4');
        v.FrameRate = 10;
        open(v);
        
        figure;
        hAx = axes('Position', [0.1, 0.2, 0.8, 0.7]);
        hImage = imshowpair(squeeze(fixedImage(:, 1, :)), ...
                            squeeze(registeredImage(:, 1, :)), ...
                            'falsecolor');
        title(['Slice along Y-axis at index 1']);
        
        for sliceIdx = 1:size(fixedImage, 2)
            imshowpair(squeeze(fixedImage(:, sliceIdx, :)), ...
                       squeeze(registeredImage(:, sliceIdx, :)), ...
                       'falsecolor', 'Parent', hAx);
            title(hAx, ['Slice along Y-axis at index ', num2str(sliceIdx)]);
            
            frame = getframe(gcf);
            
            writeVideo(v, frame);
        end
        
        close(v);
        
        disp(['Video saved as ', videoFilename]);
    else
        error('Invalid dimension input. Use ''x'', ''y'', or ''z''.');
    end
end