% Date: 2022/10/25
% Author: 陈婉晴，陈傲霜
% 相较于V1的改进：
% 1. 删除去除趋势项和季节效应
% 2. 增加mu属性
% 3.修改某些property的计算方式
% 4.不检验t

classdef PairTradingSignalV6 < handle
    properties (Access = public)
        stockUniverse;              % (stockWindTicker, stockShortName)
        propertyList = {'Validity', 'Zscore', 'Dislocation', 'ExpectedReturn','Halflife', 'alpha', 'beta', 'sigma', 'mu','LowerBound', 'UpperBound'};
        signalOutput = zeros(1, 1, 1, 11);  % （time stock1 stock2 property）
        regAlphaHistory = [];  %常数项alpha
        regBetaHistory = [];   %股票价格beta
        windowSmooth; %平滑beta时间窗口
        windowReg; %回归时间窗口
        windowTest; %检验参数平稳性时间窗口
        startDate;  %signal计算开始日期
        endDate;    %signal计算结束日期
        startDateLoc; %startDate在dateList中的位置
        endDateLoc;   %endDate在dateList中的位置
        dateList;     %cell，(date code: num, actual date: char), 所有的交易日信息
        forwardPrices = [];  %所有交易日【不仅是回测期间】所选股票的前复权收盘价
        stockLoc;     %所选行业股票所在位置
        stockNum;     %所选行业股票数量
        
    end
    
    methods (Access = public) 
        function obj = PairTradingSignalV6(startDate, endDate, windowSmooth, windowReg,stock_sector, windowTest)
            % stock_sector: 所选板块代码，31为银行业
            obj.windowSmooth = windowSmooth;
            obj.windowReg = windowReg;
            obj.startDate = startDate;
            obj.endDate = endDate;
            obj.windowTest = windowTest;
            obj.selectStockUniverse(stock_sector);
        end
            
        function obj = selectStockUniverse(obj, stock_sector)
            %获取所选行业股票的基本信息
            marketData = mclasses.staticMarketData.BasicMarketLoader.getInstance();
            generalData = marketData.getAggregatedDataStruct;
            stockSectorFilter = generalData.stock.sectorClassification.levelOne == stock_sector;
            stockLocation = find(sum(stockSectorFilter) > 1);
            obj.stockLoc = stockLocation;
            obj.stockNum = length(stockLocation);
            obj.forwardPrices = generalData.stock.properties.fwd_close(:, stockLocation);
            
            %obj.stockUniverse{i,1} 返回股票i的code
            %obj.stockUniverse{i,2} 返回股票i的中文名
            code=generalData.stock.description.tickers.officialTicker(stockLocation);
            shortname = generalData.stock.description.tickers.shortName(stockLocation);
            obj.stockUniverse = [code,shortname];
            
            %交易日信息
            dateId = generalData.sharedInformation.allDates;
            realDate = generalData.sharedInformation.allDateStr;
            dateId = num2cell(dateId);
            realDate = cellstr(realDate); 
            obj.dateList = [dateId, realDate];
            
            obj.startDateLoc = find(cell2mat(obj.dateList(:,1)) == obj.startDate);
            obj.endDateLoc = find(cell2mat(obj.dateList(:,1)) == obj.endDate);
            
            %检查设置的开始日期是否符合条件
            if obj.startDateLoc <  (obj.windowReg + obj.windowTest)
                % 如果设置的开始日期太早，向前都留不够去平滑和检验参数的长度
                disp('开始时间太早了，设置晚一点吧！');
                quit(1);
            end
        end
        
        function [Y,X] = cointegration(obj,dateLoc,stock1,stock2)
            %协整
            Y = obj.forwardPrices(dateLoc-obj.windowReg+1:dateLoc,stock1);
            X = obj.forwardPrices(dateLoc-obj.windowReg+1:dateLoc,stock2);
            
            %计算Y 和 X 中的空值数量
            YNaNNum = sum(isnan(Y));
            XNaNNum = sum(isnan(X));
            % 统计Y 和 X 中的每种价格的频率
            Y_stat = tabulate(Y);
            X_stat = tabulate(X);
            
            %如果Y或者X中有空值/X和Y中相同价格出现次数超过20%则直接剔除该配对（可能为ST股票）
            if YNaNNum+XNaNNum >= 1 || max(Y_stat(:,3)) > 20|| max(X_stat(:,3)) > 20
                obj.regAlphaHistory(stock1,stock2,dateLoc) = NaN;
                obj.regBetaHistory(stock1,stock2,dateLoc) = NaN;
            else
                %计算没加时间项的回归结果，如果通过了ADF test，那么property的计算用这里的回归结果
                [b,~] = regress(Y,[ones(obj.windowReg,1), X]);
                obj.regAlphaHistory(stock1,stock2,dateLoc) = b(1);
                obj.regBetaHistory(stock1,stock2,dateLoc) = b(2);
            end
        end
        
        function obj = initializeHistory(obj)
            %计算startDate之前windowTest-1天的alpha和beta以便用于检验稳定性和平滑处理
            %stock1和stock2分别-1和+1是为了避免和自己配对
            disp('正在初始化');
            for stock1 = 1:1:obj.stockNum-1 
                for stock2 = stock1+1:1:obj.stockNum
                    disp('---------------------');
                    disp([stock1,stock2]);
                    for dateLoc = obj.startDateLoc - obj.windowTest + 1:1:obj.startDateLoc - 1
                       [~,~] = obj.cointegration(dateLoc,stock1,stock2);
                    end
                end
            end
        end

        
        function obj = calculateProperty(obj, stock1, stock2, alpha, beta, dateLoc, residual)
            %计算配对股票的properties
            %propertyList = {'Validity', 'Zscore', 'Dislocation', 'ExpectedReturn', 
            %                'Halflife', 'alpha', 'beta', 'sigma', 'mu', 'LowerBound', 'UpperBound'};
            %标准化residual
            sigma = std(residual);
            mu = mean(residual);
            normaliedResidual = (residual - mu) / sigma;
            obj.signalOutput(dateLoc,stock1,stock2,6) = alpha;
            obj.signalOutput(dateLoc,stock1,stock2,7) = beta;
            obj.signalOutput(dateLoc,stock1,stock2,8) = sigma;
            obj.signalOutput(dateLoc,stock1,stock2,9) = mu;
            
            %dislocation: 即residual的最后一个值
            dislocation = residual(end);
            obj.signalOutput(dateLoc,stock1,stock2,3) = dislocation;
            
            %z-score: 即residual标准化后的最后一个值
            zScore = normaliedResidual(end);
            obj.signalOutput(dateLoc,stock1,stock2,2) = zScore;
            
            %halflife
            [~,~,lambda] = OU_Calibrate_LS(normaliedResidual,1); %天为单位
            halfLife = log(2)/lambda;
            obj.signalOutput(dateLoc,stock1,stock2,5) = halfLife;  
            
            %expeted return
            expectedReturn = (abs(zScore) / 2) / halfLife * 252; %年期望收益
            obj.signalOutput(dateLoc,stock1,stock2,4) = expectedReturn;
         
            %LowerBound 和 UpperBound
            lowerBond = -2;
            upperBond = 2;
            obj.signalOutput(dateLoc,stock1,stock2,10) = lowerBond;
            obj.signalOutput(dateLoc,stock1,stock2,11) = upperBond;
        end           
        
        function obj = generateSignal(obj,dateCode)
            %计算startDate和endDate之间每个交易日的signal
            dateLoc = find(cell2mat(obj.dateList(:,1)) == dateCode);
            disp('---------------------');
            disp(obj.dateList(dateLoc,2));
            for stock1 = 1:1:obj.stockNum-1
                for stock2 = stock1+1:1:obj.stockNum
                    notCointegration = true;
                    %disp([stock1,stock2,dateLoc]);
                    [Y,X] = obj.cointegration(dateLoc,stock1,stock2);
                    regressionAlphaHistory = obj.regAlphaHistory(stock1,stock2,dateLoc - obj.windowTest + 1:dateLoc);
                    regressionBetaHistory = obj.regBetaHistory(stock1,stock2,dateLoc - obj.windowTest + 1:dateLoc);
                    alphaNaNNum = sum(isnan(regressionAlphaHistory));
                    betaNaNNum = sum(isnan(regressionBetaHistory));
                    if alphaNaNNum+betaNaNNum == 0            
                        alphaSeries = zeros(obj.windowTest,1);
                        alphaSeries(:,1) = regressionAlphaHistory; %常数项
                        betaSeries = zeros(obj.windowTest,1);
                        betaSeries(:,1) = regressionBetaHistory;
                        wilNum = floor(obj.windowTest/2);
                        %平稳性检验
                        [~,h_alpha] = ranksum(alphaSeries(1:wilNum,1),alphaSeries(obj.windowTest-wilNum+1:obj.windowTest,1));
                        [~,h_beta] = ranksum(betaSeries(1:wilNum,1),betaSeries(obj.windowTest-wilNum+1:obj.windowTest,1));
                        if h_alpha == 0 && h_beta == 0
                            %如果参数平稳性检验通过,用不加t的回归参数计算残差
                            averageAlpha = mean(obj.regAlphaHistory(stock1,stock2,dateLoc - obj.windowSmooth + 1:dateLoc));
                            averageBeta = mean(obj.regBetaHistory(stock1,stock2,dateLoc - obj.windowSmooth + 1:dateLoc));
                            residual = Y - averageAlpha - averageBeta*X;
                            [~,p] = adftest(residual);
                            %如果残差通过ADF test,那么这两只股票可以配对,validity设置为1
                            if p <= 0.05
                                obj.signalOutput(dateLoc,stock1,stock2,1) = 1;
                                obj.calculateProperty(stock1, stock2, averageAlpha, averageBeta, dateLoc, residual);
                                notCointegration = false;
                            %如果残差未通过ADF test,那么这两只股票不能配对,validity设置为0
                            end
                        end
                    end
                    if notCointegration
                        obj.signalOutput(dateLoc,stock1,stock2,:) = zeros(11,1);
                    end
                end
            end
        end
    end   
end
