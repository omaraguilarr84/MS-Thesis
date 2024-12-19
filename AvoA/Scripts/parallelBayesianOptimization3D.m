function parallelBayesianOptimization3D()
    % Define the optimization variables
    learningRateRange = logspace(-5, 0, 10); % Log scale from 1e-5 to 1
    stepSizeRange = linspace(1, 50, 10);     % Linear scale from 1 to 50

    % Create all combinations of parameters
    [learningRates, stepSizes] = ndgrid(learningRateRange, stepSizeRange);
    params = [learningRates(:), stepSizes(:)];

    % Preallocate results
    scores = zeros(size(params, 1), 1);

    fprintf('Starting parallel evaluations for 3D registration');
    tic; % Start timing

    parfor i = 1:size(params, 1)
        learningRate = params(i, 1);
        stepSize = params(i, 2);
        scores(i) = evaluateRegistration3D(learningRate, stepSize);
        fprintf('Completed evaluation %d/%d\n', i, size(params, 1));
    end

    toc; % End timing
    fprintf('Parallel evaluations complete.');

    % Find the best parameters
    [~, bestIdx] = min(scores);
    bestLearningRate = params(bestIdx, 1);
    bestStepSize = params(bestIdx, 2);

    fprintf('Optimal Learning Rate: %f\n', bestLearningRate);
    fprintf('Optimal Step Size: %f\n', bestStepSize);
end