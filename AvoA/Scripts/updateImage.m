function updateImage(slider, ax, im1, im2, dimension)
    currentSlice = round(slider.Value);

    switch dimension
        case 'z'
            % Slice along Z-dimension (XY plane)
            fixedSlice = im1(:, :, currentSlice);
            registeredSlice = im2(:, :, currentSlice);
        case 'x'
            % Slice along X-dimension (YZ plane)
            fixedSlice = squeeze(im1(currentSlice, :, :));
            registeredSlice = squeeze(im2(currentSlice, :, :));
        case 'y'
            % Slice along Y-dimension (XZ plane)
            fixedSlice = squeeze(im1(:, currentSlice, :));
            registeredSlice = squeeze(im2(:, currentSlice, :));
        otherwise
            error('Invalid dimension input. Use ''x'', ''y'', or ''z''.');
    end

    % Ensure fixedSlice and registeredSlice are 2D for imshowpair
    fixedSlice = squeeze(fixedSlice);
    registeredSlice = squeeze(registeredSlice);

    % Display the pair of images
    imshowpair(fixedSlice, registeredSlice, 'falsecolor', 'Parent', ax);
    title(ax, ['Slice along ', upper(dimension), '-axis at index ', num2str(currentSlice)]);
end
