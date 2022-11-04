classdef HomeworkDirector2 < mclasses.director.HFDirector
    
    properties (GetAccess = public, SetAccess = private)
    end
    
    methods (Access = public)
        
        function obj = HomeworkDirector2(container, name)
            obj@mclasses.director.HFDirector(container, name);
        end
        
        function run(obj)
            obj.currDate = obj.calculateStartDate();
            aggregatedDataStruct = obj.marketData.aggregatedDataStruct;
            while obj.currDate <= obj.endDate
                if intersect(obj.currDate,aggregatedDataStruct.sharedInformation.allDates) 
                    currDate = obj.currDate;
                    obj.beforeMarketOpen(currDate);
                    obj.recordDailyPnlBOD(currDate);
                    obj.executeOrder(currDate);
                    obj.afterMarketClose(currDate);
                    obj.recordDailyPnl(currDate);
                    obj.examCash(currDate);
                    obj.allocatorRebalance(currDate);
                    obj.updateLFStrategy(currDate);
    
                end
                obj.currDate = obj.currDate + 1;
            end
         
        end
    end
end
