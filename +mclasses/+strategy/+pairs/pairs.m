classdef pairs < mclasses.strategy.LFBaseStrategy
    properties
        validPairs = []; % 每天有效的pairs
        stockList = []
        pairHistory = []
        longList = [];
        longPos = [];
        shortPos =[];
        shortList = [];
        signal
        holdingCount = 0;
        tradeble = 0;
        %以下是可调整参数
        N = 0.95; % 仓位大小
        MaxNumofPairs = 10; %最多持有的对数
        cutlosspara = 3; %止损点
        takeprofitpara = 0.8; %止盈点
        maxholdingdays = 40; %最多持有的天数
        minholdingdays = 10; %最少持有的天数 
        continuesinvaliddays = 8; %连续多少天invalid才视作无效
        continuesvaliddays = 2;%连续多少天valid才视为有效
        returnmultiple = 2; %存在一个新的pair，其expected return超过持有的pair expected return的X倍
        %限制每种类型关仓画图的数量，不然太多了
        pictureMax = 1; %每种类型最多画10个图
        pictureNum1 = 0;
        pictureNum2 = 0;
        pictureNum3 = 0;
        pictureNum4 = 0;
        pictureNum5 = 0;
        pictureNum6 = 0;
        
    end
    methods
        function obj = pairs(container, name)
            obj@mclasses.strategy.LFBaseStrategy(container, name);
            obj.signal = load('sector21_signalV62018010420200123(50+5)').signal;
        end
    end
    methods

        %% prepare valid pairs
        function preparePairs(obj, currDate, ~)
            SignalSize = size(obj.signal.signalOutput);
            dateLoc = find(cell2mat(obj.signal.dateList(:,1)) == currDate);
            for i = 1:SignalSize(2)
                for j = i+1:SignalSize(3)
                   pairProperty =  obj.signal.signalOutput(dateLoc,i,j,:);         
                   if  all(obj.signal.signalOutput(dateLoc - obj.continuesvaliddays: dateLoc,i,j,1)) == 1 && (obj.signal.signalOutput(dateLoc,i,j,2) > obj.signal.signalOutput(dateLoc,i,j,11) && obj.signal.signalOutput(dateLoc,i,j,2) < 3 || obj.signal.signalOutput(dateLoc,i,j,2) < obj.signal.signalOutput(dateLoc,i,j,10) && abs(obj.signal.signalOutput(dateLoc,i,j,2)) <3)% % 有效
                       %property 1-11依次代表{'Validity', 'Zscore', 'Dislocation', 'ExpectedReturn','Halflife', 
                       % 'alpha', 'beta', 'sigma', 'mu', 'LowerBound', 'UpperBound'};
                       validPair.Validty = pairProperty(1);
                       validPair.Zscore = pairProperty(2);
                       validPair.Dislocation = pairProperty(3);
                       validPair.ExpectedReturn = pairProperty(4);
                       validPair.Halflife = pairProperty(5);
                       validPair.alpha = pairProperty(6);
                       validPair.beta = pairProperty(7);
                       validPair.sigma = pairProperty(8);
                       validPair.mu = pairProperty(9);
                       validPair.LowerBound = pairProperty(10);
                       validPair.UpperBound = pairProperty(11);
                       validPair.stockLoc = [obj.signal.stockLoc(i);obj.signal.stockLoc(j)];
                       validPair.hold = 0;
                       hold = 0;
                       for k = 1:length(obj.pairHistory)
                           comp = obj.pairHistory(k).tickerPair == validPair.stockLoc;
                           if comp(1) && comp(2) && (obj.pairHistory(k).currhold == 1)
                               hold = 1;
                               break
                           end
                       end 
                       if hold == 0 
                           obj.validPairs = [obj.validPairs, validPair];
                       end
                   end
                end
            end

            if not(isempty(obj.validPairs))
                [~, order] = sort([obj.validPairs(:,:,:,:,:,:,:,:,:,:).ExpectedReturn],'descend');
                obj.validPairs = obj.validPairs(order);
            end
            if size(obj.validPairs) >= obj.MaxNumofPairs
                obj.validPairs = obj.validPairs(1:11);
            end
        end

        %% generate orders
        function [orderList, delayList] = generateOrders(obj, currDate, ~)

            orderList = [];
            delayList = [];
            obj.getPos(currDate);
            aggregatedDataStruct = obj.marketData.aggregatedDataStruct;
            [~, dateLoc] = ismember(currDate, aggregatedDataStruct.sharedInformation.allDates);  %dateloc日期的位置
%             stFilter = ~aggregatedDataStruct.stock.stTable(dateLoc, :); 
%             suspensionFilter = aggregatedDataStruct.stock.tradeDayTable(dateLoc, :);
%             currFilter = stFilter & suspensionFilter;

            %% update pairHistory
            obj.updatePairHistory(dateLoc);

            %% prepare valid pairs
            obj.preparePairs(currDate);
            
            %% open trade
            for i = 1:length(obj.validPairs) 
                if obj.holdingCount >= obj.MaxNumofPairs % 卡槽满了
                    break;
                end
                windTickers = aggregatedDataStruct.stock.description.tickers.windTicker(obj.validPairs(i).stockLoc);
                windName = aggregatedDataStruct.stock.description.tickers.shortName(obj.validPairs(i).stockLoc);
                selectedPrices = aggregatedDataStruct.stock.properties.close(dateLoc, obj.validPairs(i).stockLoc);
                if (isnan(selectedPrices(1)) || isnan(selectedPrices(2)))
                    continue
                end
                availableCash = obj.accounts('stockAccount').cashAvailable;
                if obj.validPairs(i).Zscore > obj.validPairs(i).UpperBound && abs(obj.validPairs(i).Zscore) < 2.5 && obj.validPairs(i).beta >0
                    targetShortPosition = floor(availableCash*obj.N/obj.MaxNumofPairs/(obj.validPairs(i).beta*selectedPrices(2)+selectedPrices(1)) /100)*100;
                    targetLongPosition = floor(obj.validPairs(i).beta * targetShortPosition/100)*100;
%                     longList = [longList,windTickers(2)];
%                     longPos = [longPos, targetLongPosition];
%                     shortList = [shortList, windTickers(1)];
%                     shortPos = [shortPos,targetShortPosition];
                    obj.findAndSet( targetLongPosition, windTickers(2),obj.validPairs(i).stockLoc(2),targetShortPosition,windTickers(1),obj.validPairs(i).stockLoc(1),dateLoc);
                    % 记录pairHistory
                    if obj.tradeble ~= 0
                        pairHistorycolumn.tickerPair = obj.validPairs(i).stockLoc;
                        pairHistorycolumn.position = [targetShortPosition,targetLongPosition];
                        pairHistorycolumn.Longshort = [-1, 1];
                        pairHistorycolumn.entryDate = dateLoc;
                        pairHistorycolumn.exitDate = dateLoc;
                        pairHistorycolumn.capital = targetShortPosition*selectedPrices(1)-targetLongPosition*selectedPrices(2); 
                        pairHistorycolumn.pnl = 0;
                        pairHistorycolumn.currhold = 1;
                        pairHistorycolumn.property = obj.validPairs(i);
                        pairHistorycolumn.closeCause = 0;
                        obj.validPairs(i).hold = 1;
                        obj.pairHistory = [obj.pairHistory, pairHistorycolumn];
                        d = [obj.signal.dateList{:,1}];
                        dd = datestr(d(pairHistorycolumn.entryDate),'yyyy-mm-dd');
                        disp(['日期：',dd, '开仓做多',windTickers(2),obj.validPairs(i).stockLoc(2),targetLongPosition,'做空',obj.validPairs(i).stockLoc(1),targetShortPosition]);
                        obj.holdingCount = obj.holdingCount +1;
                    end
                    
                elseif obj.validPairs(i).Zscore < obj.validPairs(i).LowerBound && obj.validPairs(i).Zscore > -3 && obj.validPairs(i).beta > 0
                    targetLongPosition = floor(availableCash*obj.N / obj.MaxNumofPairs/(obj.validPairs(i).beta * selectedPrices(2) + selectedPrices(1)) /100) * 100;
                    targetShortPosition = floor(obj.validPairs(i).beta * targetLongPosition / 100) * 100;
                    obj.findAndSet( targetLongPosition,windTickers(1),obj.validPairs(i).stockLoc(1), targetShortPosition,windTickers(2),obj.validPairs(i).stockLoc(2),dateLoc);
                    % 记录pairHistory
                     if obj.tradeble ~= 0
                        pairHistorycolumn.tickerPair = obj.validPairs(i).stockLoc;
                        pairHistorycolumn.position = [targetLongPosition,targetShortPosition];
                        pairHistorycolumn.Longshort = [1, -1];
                        pairHistorycolumn.entryDate = dateLoc;
                        pairHistorycolumn.exitDate = dateLoc;
                        pairHistorycolumn.capital = targetLongPosition * selectedPrices(1) - targetShortPosition * selectedPrices(2); 
                        pairHistorycolumn.pnl = 0;
                        pairHistorycolumn.currhold = 1;
                        pairHistorycolumn.property = obj.validPairs(i);
                        pairHistorycolumn.closeCause = 0;
                        obj.pairHistory = [obj.pairHistory, pairHistorycolumn];
                        obj.validPairs(i).hold = 1; % 已经选过了
                        d = [obj.signal.dateList{:,1}];
                        dd = datestr(d(dateLoc),'yyyy-mm-dd');
                        disp(['日期：',dd, '开仓做多',windTickers(1),obj.validPairs(i).stockLoc(1),targetLongPosition,'做空',obj.validPairs(i).stockLoc(2),targetShortPosition]);
                        obj.holdingCount = obj.holdingCount +1;
                     end
                end
            end

            %% close trade 检查所有的pair，有没有要close的
            for i = 1:length(obj.pairHistory)
                % 最短持仓时间为10天，买入后10天内均不关仓。15天后的关仓条件：
                % 1. 不满足协整关系（valid = 0)
                % 2. Expected return已经达到
                % 3. 存在一个新的pair，其expected return超过持有的pair expected return的 2 倍
                % 4. 太久没有回到均值区间（超过30天）
                % 5. resdual超过 4 sigma区间，止损
                % 6. 回到均值区间【小于 1 sigma】，止盈

                if obj.pairHistory(i).entryDate <= dateLoc - obj.minholdingdays && obj.pairHistory(i).currhold == 1 % 目前持有的话才需要检查
                    closeFlag = 0;
                    
                    stock1 = find(obj.signal.stockLoc==obj.pairHistory(i).tickerPair(1));
                    stock2 = find(obj.signal.stockLoc==obj.pairHistory(i).tickerPair(2));

                    % 查找开仓日的beta和alpha，用开仓日的sigma和alpha计算residual
%                   selectedPrices = aggregatedDataStruct.stock.properties.fwd_close(dateLoc, [stock1,stock2]);
                    selectedPrices = obj.signal.forwardPrices(dateLoc,[stock1,stock2]);
                    entryDate = obj.pairHistory(i).entryDate(end);
                    averageAlpha = obj.signal.signalOutput(entryDate,stock1,stock2,6);
                    averageBeta = obj.signal.signalOutput(entryDate,stock1,stock2,7);
                    residual = selectedPrices(1) - averageAlpha - averageBeta * selectedPrices(2);
                    zScore = (residual - obj.signal.signalOutput(entryDate, stock1,stock2,9)) / obj.signal.signalOutput(entryDate, stock1,stock2,8); 

                    % 存在一个新的pair，其expected return超过持有的pair expected return的 2 倍
                    if obj.signal.signalOutput(dateLoc - obj.continuesinvaliddays: dateLoc, stock1,stock2,1) == 0     % 关仓1：不满足协整关系（valid = 0)
                        closeFlag = 1;
                        closeCause = '不满足协整关系';
                        
                    elseif abs(zScore) > obj.cutlosspara
                        closeFlag = 5;
                        closeCause = '超过3sigma，止损';
                        
                    elseif (dateLoc - obj.pairHistory(i).entryDate(end)) > obj.maxholdingdays    % 一个pair持有时间最多为30个交易日
                        closeFlag = 4;
                        closeCause = '太久没回到均值区间';
                        
                    elseif obj.holdingCount == obj.MaxNumofPairs
                        for k = 1:length(obj.validPairs)
                            date = obj.pairHistory(i).entryDate(end);
                            if obj.validPairs(k).hold == 0 && obj.validPairs(k).ExpectedReturn > obj.returnmultiple * obj.signal.signalOutput(date(1),stock1,stock2,4)
                                closeFlag = 3;
                                obj.validPairs(k).hold = 1;
                                closeCause = '有了期望收益更高的Pair';
                                break;
                            end
                        end
                    
                     elseif obj.pairHistory(i).pnl * 252 /(obj.pairHistory(i).exitDate(end) - obj.pairHistory(i).entryDate(end)) >= obj.signal.signalOutput(obj.pairHistory(i).entryDate(end),stock1,stock2,4) * 1.5
                        closeFlag = 2;
                        closeCause = '已达到期望收益';
                    
                    elseif abs(zScore) < obj.takeprofitpara
                        closeFlag = 6;
                        closeCause = '小于1 sigma，止盈';
                    end
                 
                    if closeFlag ~= 0 
                        windTickers = aggregatedDataStruct.stock.description.tickers.windTicker([obj.pairHistory(i).tickerPair(1),obj.pairHistory(i).tickerPair(2)]);
                         % 计算仓位
                        pos = obj.pairHistory(i).position .* obj.pairHistory(i).Longshort; %原本的仓位
                         d = [obj.signal.dateList{:,1}];
                        dd = datestr(d(dateLoc),'yyyy-mm-dd');
                        if pos(1) > 0 % 做多了stock1，做空了stock2
                            obj.findAndSet(-pos(1),windTickers(1), obj.pairHistory(i).tickerPair(1), pos(2),windTickers(2),obj.pairHistory(i).tickerPair(2),dateLoc);   
                            
                        elseif pos(1) < 0 % 做多了stock2，做空了stock1
                            obj.findAndSet(-pos(2),windTickers(2),obj.pairHistory(i).tickerPair(2),  pos(1),windTickers(1),obj.pairHistory(i).tickerPair(1),dateLoc);     
                            
                        end
                        if obj.tradeble ~= 0
                             if pos(1)>0
                                 disp(['日期：',dd, '关闭做多的',windTickers(1),obj.pairHistory(i).tickerPair(1),pos(1),'关闭做空的',windTickers(2),obj.pairHistory(i).tickerPair(2),-pos(2)]);
                             else
                                 disp(['日期：',dd, '关闭做多的',windTickers(2),obj.pairHistory(i).tickerPair(2),pos(2),'关闭做空的',windTickers(1),obj.pairHistory(i).tickerPair(1),-pos(1)]);
                             end 
                                  % 关仓的时候对history要进行调整
                            obj.pairHistory(i).currhold = 0;
                            obj.pairHistory(i).exitDate(end) = dateLoc;
                            obj.pairHistory(i).closeCause(end) = closeFlag;
                           
                            
                            obj.holdingCount = obj.holdingCount - 1;
                            disp(['关闭原因：',closeCause]);
                            % 画图
%                             if closeFlag == 1 && obj.pictureNum1 < obj.pictureMax
%                                 obj.plotPair(obj.pairHistory(i));
%                             end
%                             if closeFlag == 2 && obj.pictureNum2 < obj.pictureMax
%                                 obj.plotPair(obj.pairHistory(i));
%                             end
%                             if closeFlag == 3 && obj.pictureNum3 < obj.pictureMax
%                                 obj.plotPair(obj.pairHistory(i));
%                             end
%                             if closeFlag == 4 && obj.pictureNum4 < obj.pictureMax
%                                 obj.plotPair(obj.pairHistory(i));
%                             end
%                             if closeFlag == 5 && obj.pictureNum5 < obj.pictureMax
%                                 obj.plotPair(obj.pairHistory(i));
%                             end
%                             if closeFlag == 6 && obj.pictureNum6 < obj.pictureMax
%                                 obj.plotPair(obj.pairHistory(i));
%                             end
                        end 
                       
                       
                    end
                end 
            end
            
            %% create orders
        if ~isempty(obj.longList) && obj.holdingCount <= obj.MaxNumofPairs
            shortAdjustOrder.operate = mclasses.asset.BaseAsset.ADJUST_SHORT;
            shortAdjustOrder.account = obj.accounts('stockAccount');
            shortAdjustOrder.price = obj.orderPriceType;
            shortAdjustOrder.assetCode = obj.shortList;
            shortAdjustOrder.quantity = obj.shortPos; 

            longAdjustOrder.operate = mclasses.asset.BaseAsset.ADJUST_LONG;
            longAdjustOrder.account = obj.accounts('stockAccount');
            longAdjustOrder.price = obj.orderPriceType;
            longAdjustOrder.assetCode = obj.longList; 
            longAdjustOrder.quantity = obj.longPos; 

            orderList = [orderList, longAdjustOrder];
            orderList = [orderList, shortAdjustOrder];
            delayList = [delayList, 1];
            delayList = [delayList, 1];

        end
            obj.validPairs = [];
            obj.shortList = [];
            obj.shortPos = [];
            obj.longList = [];
            obj.longPos = [];
        end
    
        %% 算头寸
        function findAndSet(obj,longpos,longwind,longloc,shortpos,shortwind,shortloc,dateLoc)
            obj.tradeble = 0;
            shortAdjustOrder.operate = mclasses.asset.BaseAsset.ADJUST_SHORT; %用来看account
            shortAdjustOrder.account = obj.accounts('stockAccount');
            [~,loc] = ismember(obj.longList,longwind(1)) ;
            idx = find(loc,1);
            if  obj.marketData.aggregatedDataStruct.stock.tradeDayTable(dateLoc, longloc) &&  obj.marketData.aggregatedDataStruct.stock.tradeDayTable(dateLoc, shortloc) && ~obj.marketData.aggregatedDataStruct.stock.stTable(dateLoc, shortloc) &&  ~obj.marketData.aggregatedDataStruct.stock.stTable(dateLoc, longloc)
                obj.tradeble = 1;
                if idx ~= 0 
                    obj.longPos(idx) = obj.longPos(idx) + longpos;
                else 
                    obj.longPos = [obj.longPos,longpos];
                    obj.longList = [obj.longList, longwind];
                end
            
            end
           
            [~,loc]  = ismember(obj.shortList,shortwind(1)) ;
            idx = find(loc,1);
             if  obj.marketData.aggregatedDataStruct.stock.tradeDayTable(dateLoc, longloc) &&  obj.marketData.aggregatedDataStruct.stock.tradeDayTable(dateLoc, shortloc)&& ~obj.marketData.aggregatedDataStruct.stock.stTable(dateLoc, shortloc) &&  ~obj.marketData.aggregatedDataStruct.stock.stTable(dateLoc, longloc)
                 obj.tradeble = 1;
                 if idx ~=0
                    obj.shortPos(idx) = obj.shortPos(idx) + shortpos;
                else
                    obj.shortPos = [obj.shortPos,shortpos];
                    obj.shortList = [obj.shortList, shortwind];
                end
             end
       
        end
        
        %% 算起始头寸
        function getPos(obj,currDate)
                shortAdjustOrder.operate = mclasses.asset.BaseAsset.ADJUST_SHORT;
                shortAdjustOrder.account = obj.accounts('stockAccount');
                shortAdjustOrder.price = obj.orderPriceType;

                ShortIx=(shortAdjustOrder.account.positionHistory(:,1)==currDate) & (shortAdjustOrder.account.positionHistory(:,3)<0);
                historyShortList=shortAdjustOrder.account.positionHistory(ShortIx,2);
                a = obj.marketData.aggregatedDataStruct.stock.description.tickers.windTicker(historyShortList(1:end));
                obj.shortList= a';
                historyShortPos = shortAdjustOrder.account.positionHistory(ShortIx,3);
                obj.shortPos = -historyShortPos(1:end)';
               
                longAdjustOrder.operate = mclasses.asset.BaseAsset.ADJUST_LONG;
                longAdjustOrder.account = obj.accounts('stockAccount');
                longAdjustOrder.price = obj.orderPriceType;

                LongIx=(longAdjustOrder.account.positionHistory(:,1)==currDate)&(longAdjustOrder.account.positionHistory(:,3)>0);
                LongIx(end)=0; %删去现金账户
                historyLongList=longAdjustOrder.account.positionHistory(LongIx,2);
                b = obj.marketData.aggregatedDataStruct.stock.description.tickers.windTicker(historyLongList(1:end));
                obj.longList= b';
                historyLongPos=longAdjustOrder.account.positionHistory(LongIx,3);
                obj.longPos= historyLongPos(1:end)';
        end 
        

        %% 更新PnL
        function updatePairHistory(obj, dateLoc,~)
           d = [obj.signal.dateList{:,1}];
           dd = datestr(d(dateLoc),'yyyy-mm-dd');
           disp(["检查开盘前持仓","日期",dd]);
           for i = 1: length(obj.pairHistory)
               if obj.pairHistory(i).currhold == 1
                   aggregatedDataStruct = obj.marketData.aggregatedDataStruct;
                   stockLoc = obj.pairHistory(i).tickerPair;
                   selectedPrices = aggregatedDataStruct.stock.properties.close(dateLoc, obj.pairHistory(i).tickerPair);
                   windTickers = aggregatedDataStruct.stock.description.tickers.windTicker(obj.pairHistory(i).tickerPair);

                   disp([windTickers(1),windTickers(2)]);
                   pct_pnl = (obj.pairHistory(i).position(1) * selectedPrices(1) - obj.pairHistory(i).position(2) * selectedPrices(2)) / obj.pairHistory(i).capital(end) -1;
%                  obj.pairHistory(i).pnl(index) = pct_pnl / (1 + obj.pairHistory(i).exitDate(index) - obj.pairHistory(i).entryDate(index)) *252;
                   obj.pairHistory(i).pnl(end) = pct_pnl;
                   obj.pairHistory(i).exitDate(end) = obj.pairHistory(i).entryDate(end);
               end
           end
       end
        
        %% 统计指标
        function summary(obj)
            history_length=length(obj.pairHistory);
            pnl=[];  
            closeReasons=[];
            sumProfit=0;
            sumLoss=0;
            for i = 1:history_length
                pnl(i)=obj.pairHistory(i).pnl;
                closeReasons(i) = obj.pairHistory(i).closeCause;
                if pnl(i)>0
                    sumProfit = sumProfit+pnl(i);
                else
                    sumLoss=sumLoss+pnl(i);
                end
            end
            winningRatio=sum(pnl>0)/history_length;
            lossRatio = 1-winningRatio;
            avg_winning_pnl = sumProfit/sum(pnl>0);
            avg_loss_pnl = sumLoss/sum(pnl<0);
            % 统计不同关仓原因造成关仓的比例
               % 1. 不满足协整关系（valid = 0)
                % 2. Expected return已经达到
                % 3. 存在一个新的pair，其expected return超过持有的pair expected return的 2 倍
                % 4. 太久没有回到均值区间（超过40天）
                % 5. resdual超过【3？】sigma区间 ，止损
                % 6. 回到均值区间【小于 1 sigma】，止盈

            % invalidRatio: 因为invalid而关仓的比例
            invalidRatio = sum(closeReasons==1) / history_length;
            % Expected return已经达到
            reachExpectedReturnRatio = sum(closeReasons==2) / history_length;
            % 存在一个新的pair，其expected return超过持有的pair expected return的 2 倍
            betterPairRatio = sum(closeReasons==3) / history_length;
            % expire trade: 太久没有回到均值区间的【4】
            expireTradeRatio = sum(closeReasons==4)/history_length;
            % cut loss: 超过3sigma【5】
            cutLossRatio = sum(closeReasons==5)/history_length;
            % take profit ratio: 主动平仓，回到均值区间
            takeProfitRatio = sum(closeReasons==6)/history_length;
            disp(['WinningRatio:', num2str(winningRatio)]);
            disp(['lossRatio:', num2str(lossRatio)]);
            disp(['avg_winning_pnl:',num2str(avg_winning_pnl)]);
            disp(['avg_loss_pnl:',num2str(avg_loss_pnl)]);
            disp(['invalidRatio:', num2str(invalidRatio)]);
            disp(['reachExpectedReturnRatio:', num2str(reachExpectedReturnRatio)]);
            disp(['betterPairRatio:', num2str(betterPairRatio)]);
            disp(['expireTradeRatio:', num2str(expireTradeRatio)]);
            disp(['cutLossRatio:', num2str(cutLossRatio)]);
            disp(['takeProfitRatio:', num2str(takeProfitRatio)]);
        end
        
        %% 画图
      function plotPair(obj, pairStruct)
            marketData = mclasses.staticMarketData.BasicMarketLoader.getInstance();
            stock1 = pairStruct.tickerPair(1); %股票index
            stock2 = pairStruct.tickerPair(2);
            stockLoc1 = find(obj.signal.stockLoc==stock1);
            stockLoc2 = find(obj.signal.stockLoc==stock2);
            aggregatedDataStruct = marketData.aggregatedDataStruct;

            windName1 = aggregatedDataStruct.stock.description.tickers.shortName(stock1);
            windName2 = aggregatedDataStruct.stock.description.tickers.shortName(stock2);
            stockName1 = windName1{1}; %stock1简称
            stockName2 = windName2{1}; %stock2简称

            entryDate=pairStruct.entryDate(end);
            exitDate=pairStruct.exitDate(end);


            % startDate和endDate两端延长几天，便于画图
            extendLength = 3;
            startDateIndexExtend = entryDate-extendLength;
            endDateIndexExtend = exitDate+1+extendLength;
            
            averageAlpha = obj.signal.signalOutput(entryDate,stockLoc1,stockLoc2,6);
            averageBeta = obj.signal.signalOutput(entryDate,stockLoc1,stockLoc2,7);
            mu = obj.signal.signalOutput(entryDate,stockLoc1,stockLoc2,9);
            sigma = obj.signal.signalOutput(entryDate,stockLoc1,stockLoc2,8);
            
           
            Price1 = aggregatedDataStruct.stock.properties.fwd_close(startDateIndexExtend:endDateIndexExtend,stock1);
            Price2 = aggregatedDataStruct.stock.properties.fwd_close(startDateIndexExtend:endDateIndexExtend,stock2);
            
            residuls = ((Price1 - averageAlpha - averageBeta*Price2)-mu)/sigma;
            upBound = 2;
            lowerBound = -2;

            % upBound = mu + 2*sigma; % 开仓时的上界
            % lowerBound =mu - 2*sigma; % 开仓时的下界

            % 作图部分
            figure
            dateList = [obj.signal.dateList{:, 1}];
            xaxis = dateList(startDateIndexExtend:endDateIndexExtend); % x轴：时间
            
            plot(xaxis, residuls, 'Color', 'black'); % 作图：pair的价格走势
            dateaxis('x', 17);
            hold on;
            
            %注明开仓、平仓时间
            hold on
            ydata=get(gca,'YLim');
            plot([dateList(entryDate+1), dateList(entryDate+1)], [min(ydata), max(ydata)], 'r-.')
            text(dateList(entryDate+1),min(ydata),[datestr(dateList(entryDate+1),'yyyy-mm-dd'),'open position'],'FontWeight','bold','Color','red','HorizontalAlignment','center')
            hold on
            plot([dateList(exitDate+1), dateList(exitDate+1)], [min(ydata), max(ydata)], 'blue-.')
            text(dateList(exitDate+1),max(ydata),[datestr(dateList(exitDate+1),'yyyy-mm-dd'),'close position'],'FontWeight','bold','Color','blue','HorizontalAlignment','center')

            % 作图：均值、上下界
            line([xaxis(1) - 1, xaxis(end)], [mu, mu], 'linestyle', ':', 'Color', 'black');
            text(xaxis(1) - 1, mu, 'Mean', 'Color', 'black');
            line([xaxis(1), xaxis(end)], [upBound, upBound], 'linestyle', ':', 'Color', 'red');
            text(xaxis(1) - 1, upBound, 'UpperBound', 'Color', 'blue');
            line([xaxis(1), xaxis(end)], [lowerBound, lowerBound], 'linestyle', ':', 'Color', 'red');
            text(xaxis(1) - 1, lowerBound, 'LowerBond', 'Color', 'blue');

            % 标明pair和平仓原因
            if pairStruct.closeCause==1
                closeCause = '不满足协整关系';
                obj.pictureNum1 = obj.pictureNum1 + 1;
            elseif pairStruct.closeCause==2
                closeCause = '已达到期望收益';
                obj.pictureNum2 = obj.pictureNum2 + 1;
            elseif pairStruct.closeCause==3
                closeCause = '有了期望收益更高的Pair';
                obj.pictureNum3 = obj.pictureNum3 + 1;
            elseif pairStruct.closeCause==4
                closeCause = '太久没回到均值区间';
                obj.pictureNum4 = obj.pictureNum4 + 1;
            elseif pairStruct.closeCause==5
                closeCause = '超过3sigma，止损';
                obj.pictureNum5 = obj.pictureNum5 + 1;
            elseif pairStruct.closeCause==6
                closeCause = 'residual回到0.5sigma均值区间';
                obj.pictureNum6 = obj.pictureNum6 + 1;
            end
            plottitle1 = ['stock pair ', '(', stockName1, ',', stockName2, ')', ' Price Movement'];
            plottitle2 = ['Closing Reason: ', closeCause];
            plottitle3 = ['pnl: ',num2str(pairStruct.pnl)];
            title({plottitle1; plottitle2;plottitle3})

      end
    end
end