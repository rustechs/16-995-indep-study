function [] = saveAndBackupData(bkpServer,bkpUser,bkpPass,localDir,remoteDir,notify_recip,data,expID)

    datetime=datestr(now);
    datetime=strrep(datetime,':','_'); %Replace colon with underscore
    datetime=strrep(datetime,'-','_'); %Replace minus sign with underscore
    datetime=strrep(datetime,' ','_'); %Replace space with underscore
    
    filename = ['simOutData_' datetime];
    
    disp('Saving data to disk...');
    
    save([localDir '/' filename],'data');
    
    try
        scp_simple_put(bkpServer,bkpUser,bkpPass,[filename '.mat'],remoteDir,localDir);
    catch err
        warning(['Unable to backup data to remote host: ' getReport(err)]);
        msg = sprintf('Something went wrong @ %s', datestr(now));
        if ~isempty(notify_recip)
            send_msg(notify_recip, expID, [msg '\n\n' getReport(err,'extended','hyperlinks','off')]);
        end
    end
    
end