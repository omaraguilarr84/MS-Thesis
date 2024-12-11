function plotOptimizationResults(filename)
    % Open and read the file
    fid = fopen(filename, 'r');
    if fid == -1
        error('Could not open the file.');
    end

    % Initialize variables
    pyramidLevels = {};
    data = struct();
    currentLevel = '';

    % Read the file line by line
    while ~feof(fid)
        line = strtrim(fgetl(fid));

        if contains(line, 'Pyramid Level:')
            % Extract pyramid level
            level = sscanf(line, 'Pyramid Level: %d');
            currentLevel = sprintf('Level%d', level);
            pyramidLevels{end+1} = currentLevel; %#ok<*AGROW>
            data.(currentLevel) = [];
        
        elseif ~isempty(currentLevel) && ~isempty(line) && ~contains(line, 'Stopping condition:') ...
                && ~contains(line, 'Warning:')
            % Try to extract iteration and MSE
            values = sscanf(line, '%f %f');
            if length(values) == 2
                data.(currentLevel)(end+1, :) = values'; % Append data
            end
        end
    end
    fclose(fid);

    % Plot data
    figure;
    hold on;
    colors = lines(length(pyramidLevels)); % Generate distinct colors
    for i = 1:length(pyramidLevels)
        level = pyramidLevels{i};
        if ~isempty(data.(level))
            plot(data.(level)(:, 1), data.(level)(:, 2), ...
                'LineWidth', 2, 'DisplayName', strrep(level, 'Level', 'Level '), 'Color', colors(i, :));
        end
    end

    % Customize plot
    title('MSE vs. Iterations for Different Pyramid Levels');
    xlabel('Iterations');
    ylabel('Mean Square Error (MSE)');
    legend('show');
    grid on;
    hold off;
end
