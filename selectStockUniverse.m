marketData = mclasses.staticMarketData.BasicMarketLoader.getInstance();
generalData = marketData.getAggregatedDataStruct;
generalData.stock
generalData.stock.sectorClassification

generalData
generalData.sectorLevelOne
generalData.sectorLevelOne.sectorFullNames

generalData.sectorLevelOne
generalData.sectorLevelOne.sectorFullNames
generalData.stock.sectorClassification
%交易日信息
dateId = generalData.sharedInformation.allDates;
realDate = generalData.sharedInformation.allDateStr;
dateId = num2cell(dateId);
realDate = cellstr(realDate); 
dateList = [dateId, realDate];
dateList=[dateList{:,1}];

financeSectorFilter = generalData.stock.sectorClassification.levelOne == 31; %指定板块代码
stockNum = sum(financeSectorFilter, 2);
figure; 
plot(dateList,stockNum);
dateaxis('x',17);
title("Number of bank stocks");
financeSectorFilter = generalData.stock.sectorClassification.levelOne == 31;
generalData.stock.description.tickers.shortName(financeSectorFilter(1,:))
generalData.stock.description.tickers.shortName(financeSectorFilter(end,:))
%% add test
% sanity check
financeSectorFilter = generalData.stock.sectorClassification.levelOne == 31;
currentResult = generalData.stock.description.tickers.shortName(financeSectorFilter(2210,:));
expectedResult = { '平安银行'
    '宁波银行'
    '浦发银行'
    '华夏银行'
    '民生银行'
    '招商银行'
    '南京银行'
    '兴业银行'
    '北京银行'
    '农业银行'
    '交通银行'
    '工商银行'
    '光大银行'
    '建设银行'
    '中国银行'
    '中信银行'
    '江阴银行'
    '无锡银行'
    '江苏银行'
    '常熟银行'
    '贵阳银行'
    '杭州银行'
    '上海银行'
    '苏农银行'
    '张家港行'
    '成都银行'
    '郑州银行'
    '长沙银行'
    '青岛银行'
    '西安银行'
    '紫金银行'
    '青农商行'
    '苏州银行'
    '渝农商行'
    '浙商银行'
    '邮储银行'};
assert(isequal(currentResult, expectedResult), 'pairTrading::stock selection::data mismatch');
% inline testing -- the reason that why we need a NamedObj class

%% correlation check
bankStockLocation = find(sum(financeSectorFilter) > 1);
generalData.stock.description.tickers.shortName(bankStockLocation)
bankFowardPrices = generalData.stock.properties.fwd_close(:, bankStockLocation);

corr(bankFowardPrices)
validStartingPoint = max(sum(isnan(bankFowardPrices)))+3;
bankCorrelationMatrix = corr(bankFowardPrices(validStartingPoint:end, :));

min(bankCorrelationMatrix)
min(min(bankCorrelationMatrix))

figure; plot(sort(bankCorrelationMatrix));
figure; plot(sort(bankCorrelationMatrix(:)));title("Correlation of prices");

%% forward adjusted prices vs close prices
bankClosePrices = generalData.stock.properties.close(:, bankStockLocation);
figure; plot(bankClosePrices);
figure; plot(bankFowardPrices);
figure; 
plot(dateList,bankFowardPrices(:,2:9));
dateaxis('x',17);
title("Forward Prices");




