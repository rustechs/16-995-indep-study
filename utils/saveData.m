function [] = save_data(localDir,filePrefix,data)

    datetime=datestr(now);
    datetime=strrep(datetime,':','_'); %Replace colon with underscore
    datetime=strrep(datetime,'-','_'); %Replace minus sign with underscore
    datetime=strrep(datetime,' ','_'); %Replace space with underscore

    filename = [filePrefix '_' datetime];

    fprintf('\n\nSaving data to disk...\n');

    save([localDir '/' filename],'-struct','data');
    
end