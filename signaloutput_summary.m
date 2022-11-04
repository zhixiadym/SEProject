%%
load 'signalV62018010420200123(30+5).mat' signal;
%%
valid_list305V6 = [];
trade_list305V6 = [];
plot_valid305V6 = zeros(signal.stockNum,signal.stockNum);
plot_trade305V6 = zeros(signal.stockNum,signal.stockNum);
%%
for dateLoc = signal.startDateLoc:signal.endDateLoc
    validNum = 0;
    tradeNum = 0;
    for stock1 = 1:1:signal.stockNum-1
        for stock2 = stock1+1:1:signal.stockNum
            valid = signal.signalOutput(dateLoc,stock1,stock2,1);
            if valid == 1
                validNum = validNum+1;
                zScore = signal.signalOutput(dateLoc,stock1,stock2,2);
                low = signal.signalOutput(dateLoc,stock1,stock2,10);
                up = signal.signalOutput(dateLoc,stock1,stock2,11);
                plot_valid305V6(stock1,stock2) = plot_valid305V6(stock1,stock2) + 1;
                if zScore>up || zScore<low
                    tradeNum = tradeNum+1;
                    disp([dateLoc,stock1,stock2]);
                    plot_trade305V6(stock1,stock2) = 1;
                end
            end
        end
    end
    valid_list305V6 = [valid_list305V6, validNum];
    trade_list305V6 = [trade_list305V6, tradeNum];
end

%%
for stock1 = 1:1:signal.stockNum-1
    for stock2 = stock1+1:1:signal.stockNum
        if plot_trade305(stock1,stock2) == 1 && plot_valid305(stock1,stock2) > 60
            figure
            plot(signal.signalOutput(signal.startDateLoc:signal.endDateLoc,stock1,stock2,1))
            hold on
            ylim([-0.4 2])
            ydata=get(gca,'YLim');
            for dateLoc = signal.startDateLoc:signal.endDateLoc
                if signal.signalOutput(dateLoc,stock1,stock2,2) > 2 || signal.signalOutput(dateLoc,stock1,stock2,2) < -2
                    plot([dateLoc-signal.startDateLoc+1, dateLoc-signal.startDateLoc+1], [min(ydata), max(ydata)], 'r-.')
                    hold on
                end
            end
        end
    end
end
 
%%
figure;
dateList=[signal.dateList{signal.startDateLoc:signal.endDateLoc,1}];
plot(dateList,trade_list305);
hold on;
plot(dateList,trade_list3012);
hold on;
plot(dateList,trade_list405);
hold on;
plot(dateList,trade_list4012);
hold on;
plot(dateList,trade_list505);
hold on;
plot(dateList,trade_list5012);
dateaxis('x',17);
title("Number of trade pairs");
legend('30+5','30+12','40+5','40+12','50+5','50+12','Location','NorthEastOutside');
%%
figure;
dateList=[signal.dateList{signal.startDateLoc:signal.endDateLoc,1}];
plot(dateList,trade_list505);
hold on;
plot(dateList,trade_list5012);
hold on;
dateaxis('x',17);
title("Number of trade pairs");
legend('50+5','50+12','Location','NorthEastOutside');
%%
figure;
dateList=[signal.dateList{signal.startDateLoc:signal.endDateLoc,1}];
plot(dateList,trade_list305);
hold on;

plot(dateList,trade_list405);
hold on;

plot(dateList,trade_list505);
hold on;
dateaxis('x',17);
title("Number of trade pairs");
legend('30+5','40+5','50+5','Location','NorthEastOutside');
%%
figure;
plot(dateList,valid_list305);
dateaxis('x',17);
title("Number of valid pairs");
legend('30+5','Location','NorthWest');