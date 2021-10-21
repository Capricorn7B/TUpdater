program Updater;

uses
  Vcl.Forms,
  uTestCheckUpdates in 'uTestCheckUpdates.pas' {frmCheckUpdates},
  uUpdater in '..\..\Source\uUpdater.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmCheckUpdates, frmCheckUpdates);
  Application.Run;
end.
