function [mcData,m] = MeanCenter(data)

    m = mean(data(:));
    mcData = data - m;

end