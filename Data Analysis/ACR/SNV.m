function [snvData] = SNV(data)

    m = mean(data(1, :));
    sdev = std(data(1, :)); 

    snvData = (data - m)/sdev;
end