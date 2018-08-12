function [] = saveAndBackupGenData(bkpServer,bkpUser,bkpPass,localDir,remoteDir,notify_recip,genStats)

    filename = ['gen_' num2str(genStats.genNum)];
    disp('Saving data to disk...');
    
    save([localDir '/' filename],'-struct','genStats');
    
    try
        scp_simple_put(bkpServer,bkpUser,bkpPass,[filename '.mat'],remoteDir,localDir);
    catch err
        warning(['Unable to backup generation data to remote host: ' getReport(err)]);
        msg = sprintf('%s: Something went wrong @ %s', genStats.experimentID, datestr(now));
        if ~isempty(notify_recip)
            send_msg(notify_recip, genStats.experimentID, [msg '\n\n' getReport(err,'extended','hyperlinks','off')]);
        end
    end
    
end