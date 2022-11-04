%%
%生成2018.1.4 - 2020.1.23区间的数据，并保存
startDate = datenum(2019, 1, 4);
endDate = datenum(2020, 1, 23);
windowSmooth  = 5;
windowReg = 30;
stock_sector = 31;
windowTest = 12;
signal = PairTradingSignalV6(startDate, endDate, windowSmooth, windowReg,stock_sector, windowTest);
signal.initializeHistory();
dateCodeDouble = cell2mat(signal.dateList(signal.startDateLoc:signal.endDateLoc,1));
[n,~] = size(dateCodeDouble);
progressBar = waitbar(0, '正在生成全部信号数据');
tStart = cputime;
%%
%计算信号，并显示进度
for d = 1:n
    tNow = cputime;
    progress = d/n;
    remainingTime = roundn((tNow - tStart) / progress * (1 - progress) / 60, -1);
    dateCode = dateCodeDouble(d,1);
    signal.generateSignal(dateCode);
    progressStr = ['正在生成全部信号数据...', num2str(roundn(progress * 100, -1)), '%，剩余时间：', ...
                                num2str(remainingTime), 'min.'];
    waitbar(progress, progressBar, progressStr);
end
save('signalV62019010420200123(30+5).mat','signal');%保存结果，调用代码为 load 'signalV52018010420200123(window_reg+window_smooth).mat' signal