unit uUpdater;

interface

uses System.Classes;

type TUpdater = class
  private
    FsRP, FsLP : string; //Remote and local path
//    FUpdateList : TStringList; //List of Updates
//    FULLoaded : Boolean; //Update list loading flag
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
    /// Loading given update file to \update\ folder
    /// </summary>
    /// <param name="sFN">File name</param>
    /// <returns>Returns True on no errors</returns>
    function LoadUpdateFile (sFN : string) : Boolean;
  public
    /// <summary>
    /// Constructor, creates object of class and set initial values
    /// </summary>
    /// <param name="siRP">"Remote" path (there we get updates)</param>
    /// <param name="siLP">Local path (path to folder parent for update folder, usually it's application folder)</param>
    constructor Create (siRP, siLP : string);
//    destructor Destroy; override;
    procedure CheckUpdates;
    function LoadUpdatesCAB (sCABName : string) : Boolean;
    function InstallUpdates : Boolean;
    function LoadUpdatesZip (sZipName : string) : Boolean;
    function UpdateFromZip : Boolean;
    property sRP : string read FsRP write FsRP;
    property sLP : string read FsLP write FsLP;
//    property UpdateList : TStringList read FUpdateList write FUpdateList;
    property NeedUpdate : Boolean read FNeedUpdate write FNeedUpdate default False;
    property LocalVersion : string read FLocalVersion write FLocalVersion;
    property RemoteVersion : string read FRemoteVersion write FRemoteVersion;
//    property ULLoaded : Boolean read FULLoaded write FULLoaded default False;
    property RemoteProtocol : Byte read FRemoteProtocol write FRemoteProtocol default 0;
    property sUsername : string read FsUsername write FsUsername;
    property sPassword : string read FsPassword write FsPassword;
    property sPath : string read FsPath write FsPath;
end;

implementation
uses idHTTP, IdFTP, IdFTPCommon, IdSSLOpenSSL, VCL.Dialogs, SysUtils, IOUtils, AbCabExt, Windows, Zip, StrUtils, System.Net.URLClient;

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

function TUpdater.LoadUpdateFile (sFN : string) : Boolean;
begin
  Result := False;
  case RemoteProtocol of
    0   :
      begin

      end;
    1,2 :
      begin
        with TIdHTTP.Create do
          try
            try
              if RemoteProtocol = 1 then
                begin
                  IOHandler := TIdSSLIOHandlerSocketOpenSSL.Create;
                  (IOHandler as TIdSSLIOHandlerSocketOpenSSL).SSLOptions.SSLVersions := [sslvSSLv2, sslvSSLv23, sslvSSLv3, sslvTLSv1, sslvTLSv1_1, sslvTLSv1_2];
                end;
              var fs := TFileStream.Create(sLP + '\update\'  + sFN, fmCreate);
              Get(sRP + sFN, fs);
            except
              on E : Exception do
                begin
                  ShowMessage('Can''t download remote update file ' + sFN + ' via HTTP/HTTPS, error: ' + E.Message);
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
            Host := sRP;
            TransferType := ftBinary;
            UserName := sUsername;
            Password := sPassword;
            try
              Connect;
              Get(sPath + sFN, sLP + '\update\'  + sFN, True, False);
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
    4   :
      begin

      end;
  end;
  Result := True;
end;

constructor TUpdater.Create (siRP, siLP : string);
begin
  if siRP = '' then
    raise Exception.Create('Set path to remote update dir!');
  inherited Create;
  sLP := IfThen(siLP = '', ExtractFileDir(ParamStr(0)), siLP);
  RemoteVersion := '';
//  UpdateList := TStringList.Create;

  if siRP.IndexOf('https') = 0 then
    begin
      sRP := siRP;
      RemoteProtocol := 1
    end
  else if siRP.IndexOf('http') = 0 then
    begin
      sRP := siRP;
      RemoteProtocol := 2;
    end
  else if siRP.IndexOf('ftp') = 0 then
    begin
      var URL := TUri.Create(siRP);     //Example ftp://user:pass@localhost/
      sRP := URL.Host;
      sUserName := URL.Username;
      sPassword := URL.Password;
      sPath := URL.Path;
      RemoteProtocol := 3;
    end
  else if TPath.IsUNCPath(siRP) then
    begin
      if TDirectory.Exists(siRP) then
        sRP := siRP
      else
        raise Exception.Create('Wrong UNC path to update files!');
      RemoteProtocol := 4;
    end
  else
    begin
      if TDirectory.Exists(siRP) then
        sRP := siRP
      else
        raise Exception.Create('Wrong path to update files!');
    end;
  try
    if TFile.Exists(sLP + '\update\version') then
      LocalVersion := TFile.ReadAllText(sLP  + '\update\version')
    else
      LocalVersion := '0.0.0.0';
    if TDirectory.Exists(sLP + '\update\') then
      TDirectory.Delete(sLP + '\update\', True);
    TDirectory.CreateDirectory(sLP + '\update\');
    TDirectory.CreateDirectory(sLP + '\update\tmp\');
    if TFile.Exists(ParamStr(0) + '.old') then
      TFile.Delete(ParamStr(0) + '.old');
    TFile.WriteAllText(sLP + '\update\version',LocalVersion);
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
    0   :
      begin

      end;
    1,2 :
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
              Get(sRP + 'version', ss);
              RemoteVersion := ss.DataString;
            except
              on E : Exception do
                begin
                  ShowMessage('Can''t download remote version file HTTP/HTTPS, error: ' + E.Message);
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
            Host := sRP;
            TransferType := ftBinary;
            UserName := sUsername;
            Password := sPassword;
            try
              Connect;
              Get(sPath + 'version', sLP + '\update\version.rt',True, False);
              RemoteVersion := TFile.ReadAllText(sLP + '\update\version.rt');
            except
              on E : Exception do
                begin
                  ShowMessage('Can''t download remote version file FTP, error: ' + E.Message);
                  Exit;
                end;
            end;
          finally
            if Connected then
              Disconnect;
            Free;
          end;
      end;
    4   :
      begin

      end;
  end;
  if CompareVersions then
    NeedUpdate := True;

end;

function TUpdater.LoadUpdatesCAB (sCABName : string) : Boolean;
  var fs : TFileStream;
begin
  Result := False;
  fs := TFileStream.Create(sLP + '\update\' + sCABName, fmCreate);
  with TIdHTTP.Create do
    try
      try
        Get(sRP + sCABName, fs);
      except
        on E : Exception do
          begin
            ShowMessage('Can''t download updates CAB file, error: ' + E.Message);
            Exit;
          end;
      end;
    finally
      Free;
      fs.Free;
    end;
  with TAbCabExtractor.Create(nil) do
    try
      try
        OpenArchive(sLP + '\update\' + sCABName);
        BaseDirectory := sLP + '\update\tmp\';
        ExtractFiles('*.*');
      except
        on E : Exception do
          begin
            ShowMessage('Can''t extract updates CAB file, error: ' + E.Message);
            Exit;
          end;
      end;
      Result := True;
    finally
      Free;
    end;
end;


function TUpdater.LoadUpdatesZip (sZipName : string) : Boolean;
begin
  Result := False;
  if LoadUpdateFile(sZipName) then
    with TZipFile.Create do
      try
        try
          Open(sLP + '\update\' + sZipName, zmRead);
          ExtractAll(sLP + '\update\tmp\');
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
  if TDirectory.IsEmpty(sLP + '\update\tmp\') then
    begin
      ShowMessage('tmp directory is empty!');
      Exit;
    end;

  if FileExists(ParamStr(0)) and FileExists(sLP + '\update\tmp\' + ExtractFileName(ParamStr(0))) then
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
    TDirectory.Copy(sLP + '\update\tmp\', sLP + '\');
  except
    on E: Exception do
      begin
        if TFile.Exists(ParamStr(0)) then

        RenameFile(ParamStr(0) + '.old', ParamStr(0));
        ShowMessage('Can''t update files');
        Exit;
      end;
  end;
  NeedUpdate := False;
  LocalVersion := RemoteVersion;
  TFile.WriteAllText(sLP + '\update\version', LocalVersion);
  Result := True;
end;

function TUpdater.UpdateFromZip: Boolean;
begin
  CheckUpdates;
  Result := NeedUpdate and LoadUpdatesZip(RemoteVersion + '.zip') and InstallUpdates;
end;



end.
