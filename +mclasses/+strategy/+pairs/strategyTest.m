%% This file serves as a test script for the LongOnly strategy

%% Create a director
director = mclasses.director.HomeworkDirector2([], 'homework');

%% register strategy
% parameters for director
directorParameters = [];
initParameters.startDate = datenum(2019, 01 ,04);
initParameters.endDate = datenum(2020, 01, 04);
director.initialize(initParameters);

% register a long only strategy
longOnlyStrategy = mclasses.strategy.pairs.pairs(director.rootAllocator , 'pairs');
strategyParameters = mclasses.strategy.longOnly.configParameter(longOnlyStrategy);
longOnlyStrategy.initialize(strategyParameters);

%% run strategies
director.reset();
director.run();

%% display results
longOnlyStrategy.summary()
director.displayResult();
