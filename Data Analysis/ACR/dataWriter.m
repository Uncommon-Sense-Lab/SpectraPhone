function [] = dataWriter(train, fn, labels,  data, cTop, cBot)
     
    p = data(:, cTop:cBot); 
    d = [labels p];
    if train == true
        f = "TrainingData/" + fn + ".csv";
        writematrix(d, f );
        %combineData
        files = dir('TrainingData/*.csv');
        len = length(files);
        data = [];
        for i=1:len
            filename = files(i).name;
            d = readmatrix(filename);
            data = [data d]; 
        end
        writematrix(data, "TrainingData/trainingData.csv" );
    else
        f = "TestingData/" + fn + ".csv"; 
        writematrix(d, f );
        %combineData
        files = dir('TestingData/*.csv');
        len = length(files);
        data = [];
        for i=1:len
            filename = files(i).name;

            d = readmatrix(filename);
            size(d')
            data = [data; d]; 
        end
        writematrix(data, "TestingData/testData.csv" );
    end

    

    


end