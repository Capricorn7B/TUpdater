unit uUpdater;

interface

uses System.Classes;

type TUpdater = class
  private
    FsRP, FsLP : string; //Remote and local path
    FNeedUpdate : Boolean; //New version on remote path flag
    FLocalVersion : string; //local version, format x.x.x.x
    FRemoteVersion : string; //remote version, format x.x.x.x
    FRemoteProtocol : Byte; //remote protocol 0 - local filesystem, 1 - http, 2 - https, 3 - ftp, 4 - unc
    FsUsername : string; //username for remote login
    FsPassword : string; //password for remote login
    FsPath : string; //path to remote resource (f.ex path on ftp server)

    /// <summary>
    /// Compare local and remote versions in format x.x.x.x
    /// </summary>
    /// <returns>Return True if remote version is higher</returns>
    function CompareVersions : Boolean;

    /// <summary>
    /// Loading given update file to update folder
    /// </summary>
    /// <param name="sFN">File name</param>
    /// <param name="sPathToFile">Relative path to file, empty by default</param>
    /// <returns>Returns True on no errors</returns>
    function LoadUpdateFile (sFN : string; sPathToFile : string = '') : Boolean;
  public
    /// <summary>
    /// Constructor, creates object of class and set initial values
    /// </summary>
    /// <param name="siRP">"Remote" path (there we get updates)</param>
    /// <param name="siLP">Local path (path to folder parent for update folder, usually it's application folder)</param>
    constructor Create (siRP, siLP : string);
//    destructor Destroy; override;

    /// <summary>
    /// CComparing remote and local versions, set NeedUpdate property true if remote version is higher
    /// </summary>
    procedure CheckUpdates;

    /// <summary>
    ///   Updating application files from update\tmp directory
    /// </summary>
    /// <returns>Returns True on update without errors</returns>
    function InstallUpdates : Boolean;

    /// <summary>
    /// Loading zip file with updates and extract it into update\tmp directory
    /// </summary>
    /// <param name="sZipName">zip filename</param>
    /// <returns>Returns True on no errors</returns>
    function LoadUpdatesZip (sZipName : string) : Boolean;

    /// <summary>
    ///   Complex function for updating from zip file.
    ///   Check versions, if remote is higher load file remote_version_number.zip (f.ex 0.0.0.1.zip),
    ///   extract updates into update\tmp directory, then update apllication files
    /// </summary>
    /// <returns>Returns True on no errors</returns>
    function UpdateFromZip : Boolean;

    property NeedUpdate : Boolean read FNeedUpdate write FNeedUpdate default False;
    property LocalVersion : string read FLocalVersion write FLocalVersion;
    property RemoteVersion : string read FRemoteVersion write FRemoteVersion;
    property RemoteProtocol : Byte read FRemoteProtocol write FRemoteProtocol default 0;
    property sUsername : string read FsUsername write FsUsername;
    property sPassword : string read FsPassword write FsPassword;
    property sPath : string read FsPath write FsPath;
end;

implementation
uses idHTTP, IdFTP, IdFTPCommon, IdSSLOpenSSL, VCL.Dialogs, SysUtils, IOUtils, Windows, Zip, StrUtils, System.Net.URLClient, UITypes;

function TUpdater.CompareVersions : Boolean;
var
  asLV, asRV : TArray<string>;
  i : Integer;
begin
  Result := False;
  asLV := LocalVersion.Split(['.']);
  asRV := RemoteVersion.Split(['.']);
  for i := 0 to 3 do
    if StrToInt(asLV[i]) < StrToInt(asRV[i]) then
      begin
        Result := True;
        Break;
      end
    else if StrToInt(asLV[i]) > StrToInt(asRV[i]) then
      Break;
end;

function TUpdater.LoadUpdateFile (sFN : string; sPathToFile : string = '') : Boolean;
begin
  Result := False;
  case RemoteProtocol of
    0, 4:
      begin
        try
          TFile.Copy(FsRP + sPathToFile + sFN, FsLP + sPathToFile + sFN, True);
        except
          on E : Exception do
            begin
              ShowMessage('Can''t copy update file ' + sFN + ' , error: ' + E.Message);
              Exit;
            end;
        end;
      end;
    1, 2:
      begin
        with TIdHTTP.Create do
          try
            try
              if RemoteProtocol = 1 then
                begin
                  IOHandler := TIdSSLIOHandlerSocketOpenSSL.Create;
                  (IOHandler as TIdSSLIOHandlerSocketOpenSSL).SSLOptions.SSLVersions := [sslvSSLv2, sslvSSLv23, sslvSSLv3, sslvTLSv1, sslvTLSv1_1, sslvTLSv1_2];
                end;
              var fs := TFileStream.Create(FsLP + sFN, fmCreate);
              Get(FsRP + sFN, fs);
            except
              on E : Exception do
                begin
                  ShowMessage('Can''t download remote update file ' + sFN + ' via ' + IfThen(RemoteProtocol = 2, 'HTTP', 'HTTPS') + ', error: ' + E.Message);
                  Exit;
                end;
            end;
          finally
            if RemoteProtocol = 1 then
              FreeAndNil(IOHandler);
            Free;
          end;
      end;
    3   :
      begin
        with TidFTP.Create do
          try
            Host := FsRP;
            TransferType := ftBinary;
            UserName := sUsername;
            Password := sPassword;
            try
              Connect;
              Get(sPath + sFN, FsLP + sFN, True, False);
            except
              on E : Exception do
                begin
                  ShowMessage('Can''t download remote version file ' + sFN + ' via FTP, error: ' + E.Message);
                  Exit;
                end;
            end;
          finally
            if Connected then
              Disconnect;
            Free;
          end;
      end;
  end;
  Result := True;
end;

constructor TUpdater.Create (siRP, siLP : string);
begin
  if siRP = '' then
    raise Exception.Create('Set path to remote update dir!');
  inherited Create;
  if siLP = '' then
    FsLP := ExtractFilePath(ParamStr(0)) + 'update\'
  else
    FsLP := siLP;
  RemoteVersion := '';
  if siRP.IndexOf('https') = 0 then
    begin
      FsRP := siRP;
      RemoteProtocol := 1
    end
  else if siRP.IndexOf('http') = 0 then
    begin
      FsRP := siRP;
      RemoteProtocol := 2;
    end
  else if siRP.IndexOf('ftp') = 0 then
    begin
      var URL := TUri.Create(siRP);     //Example ftp://user:pass@localhost/
      FsRP := URL.Host;
      sUserName := URL.Username;
      sPassword := URL.Password;
      sPath := URL.Path;
      RemoteProtocol := 3;
    end
  else if TPath.IsUNCPath(siRP) then
    begin
      if TDirectory.Exists(siRP) then
        FsRP := siRP
      else
        raise Exception.Create('Wrong UNC path to update files!');
      RemoteProtocol := 4;
    end
  else
    begin
      if TDirectory.Exists(siRP) then
        FsRP := siRP
      else
        raise Exception.Create('Wrong path to update files!');
    end;
  try
    if TFile.Exists(FsLP + 'version') then
      LocalVersion := TFile.ReadAllText(FsLP  + 'version')
    else
      LocalVersion := '0.0.0.0';
    if TDirectory.Exists(FsLP) then
      TDirectory.Delete(FsLP, True);
    while not TDirectory.Exists(FsLP) do
      begin
        TDirectory.CreateDirectory(FsLP);
        if (not TDirectory.Exists(FsLP)) and
           (MessageDlg('Can''t create update dir. Try again?', mtConfirmation, [mbYes, mbNo], 0, mbYes) = mrNo) then
          raise Exception.Create('Error update dir create');
      end;
    while not TDirectory.Exists(FsLP + 'tmp\') do
      begin
        TDirectory.CreateDirectory(FsLP + 'tmp\');
        if (not TDirectory.Exists(FsLP + 'tmp\')) and
           (MessageDlg('Can''t create update\tmp dir. Try again?', mtConfirmation, [mbYes, mbNo], 0, mbYes) = mrNo) then
          raise Exception.Create('Error update\tmp dir create');
      end;
    if TFile.Exists(ParamStr(0) + '.old') then
      TFile.Delete(ParamStr(0) + '.old');
    TFile.WriteAllText(FsLP + 'version', LocalVersion);
  except
    on E : Exception do
      ShowMessage('Error updater create/deleting tmp files: ' + E.Message);
  end;
end;

//destructor TUpdater.Destroy;
//begin
//  FreeAndNil(UpdateList);
//  inherited Destroy;
//end;

procedure TUpdater.CheckUpdates;
begin
  case RemoteProtocol of
    0, 4:
      begin
        RemoteVersion := TFile.ReadAllText(FsRP + 'version');
      end;
    1, 2:
      begin
        with TIdHTTP.Create do
          try
            try
              if RemoteProtocol = 1 then
                begin
                  IOHandler := TIdSSLIOHandlerSocketOpenSSL.Create;
                  (IOHandler as TIdSSLIOHandlerSocketOpenSSL).SSLOptions.SSLVersions := [sslvSSLv2, sslvSSLv23, sslvSSLv3, sslvTLSv1, sslvTLSv1_1, sslvTLSv1_2];
                end;
              var ss := TStringStream.Create;
              Get(FsRP + 'version', ss);
              RemoteVersion := ss.DataString;
            except
              on E : Exception do
                begin
                  ShowMessage('Can''t download remote version file via ' + IfThen(RemoteProtocol = 2, 'HTTP', 'HTTPS') + ', error: ' + E.Message);
                  Exit;
                end;
            end;
          finally
            if RemoteProtocol = 1 then
              FreeAndNil(IOHandler);
            Free;
          end;
      end;
    3   :
      begin
        with TidFTP.Create do
          try
            Host := FsRP;
            TransferType := ftBinary;
            UserName := sUsername;
            Password := sPassword;
            try
              Connect;
              Get(sPath + 'version', FsLP + 'version.rt', True, False);
              RemoteVersion := TFile.ReadAllText(FsLP + 'version.rt');
            except
              on E : Exception do
                begin
                  ShowMessage('Can''t download remote version file via FTP, error: ' + E.Message);
                  Exit;
                end;
            end;
          finally
            if Connected then
              Disconnect;
            Free;
          end;
      end;
  end;
  NeedUpdate := CompareVersions;
end;

function TUpdater.LoadUpdatesZip (sZipName : string) : Boolean;
begin
  Result := False;
  if LoadUpdateFile(sZipName) then
    with TZipFile.Create do
      try
        try
          Open(FsLP + sZipName, zmRead);
          ExtractAll(FsLP + 'tmp\');
        except
          on E : Exception do
            begin
              ShowMessage('Can''t extract updates Zip file, error: ' + E.Message);
              Exit;
            end;
        end;
        Result := True;
      finally
        Free;
      end;
end;

function TUpdater.InstallUpdates : Boolean;
begin
  Result := False;
  if TDirectory.IsEmpty(FsLP + 'tmp\') then
    begin
      ShowMessage('tmp directory is empty!');
      Exit;
    end;

  if FileExists(ParamStr(0)) and FileExists(FsLP + 'tmp\' + ExtractFileName(ParamStr(0))) then
    try
      RenameFile(ParamStr(0), ParamStr(0) + '.old');
    except
      on E: Exception do
        begin
          ShowMessage('Can''t rename main exe file');
          Exit;
        end;
    end;
  try
    TDirectory.Copy(FsLP + 'tmp\', ExtractFilePath(ParamStr(0)) + '\');
  except
    on E: Exception do
      begin
        if (not TFile.Exists(ParamStr(0))) and TFile.Exists(ParamStr(0) + '.old') then
          RenameFile(ParamStr(0) + '.old', ParamStr(0));
        ShowMessage('Can''t update files');
        Exit;
      end;
  end;
  NeedUpdate := False;
  LocalVersion := RemoteVersion;
  TFile.WriteAllText(FsLP + 'version', LocalVersion);
  Result := True;
end;

function TUpdater.UpdateFromZip: Boolean;
begin
  CheckUpdates;
  Result := NeedUpdate and LoadUpdatesZip(RemoteVersion + '.zip') and InstallUpdates;
end;



end.
