unit uTestCheckUpdates;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls;

type
  TfrmCheckUpdates = class(TForm)
    edtUrl: TEdit;
    lblURL: TLabel;
    btnCheck: TButton;
    edtLocal: TEdit;
    lblLocal: TLabel;
    procedure btnCheckClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmCheckUpdates: TfrmCheckUpdates;

implementation
uses uUpdater, ShellAPI;
{$R *.dfm}

procedure TfrmCheckUpdates.btnCheckClick(Sender: TObject);
begin
  with TUpdater.Create(edtUrl.Text, edtLocal.Text) do
    begin
      if UpdateFromZip then
        begin
          ShowMessage('Application restart');
          ShellExecute(0, 'open', PWideChar(Paramstr(0)), PWideChar('/update'), nil, SW_SHOWNORMAL);
          Application.Terminate;
        end
      else
        ShowMessage('No updates');
      Free;
    end;

end;

procedure TfrmCheckUpdates.FormCreate(Sender: TObject);
begin
  if (ParamCount > 1) and (Paramstr(1) = '/update') then
    ShowMessage('Application updated');
end;

end.
