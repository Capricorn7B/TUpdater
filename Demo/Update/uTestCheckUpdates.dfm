object frmCheckUpdates: TfrmCheckUpdates
  Left = 0
  Top = 0
  Caption = 'Check Updates'
  ClientHeight = 524
  ClientWidth = 753
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object lblURL: TLabel
    Left = 40
    Top = 27
    Width = 85
    Height = 13
    Caption = 'URL to update list'
  end
  object lblLocal: TLabel
    Left = 40
    Top = 59
    Width = 112
    Height = 13
    Caption = 'Path to local update list'
  end
  object edtUrl: TEdit
    Left = 184
    Top = 24
    Width = 537
    Height = 21
    TabOrder = 0
    Text = 'ftp://user:pass@localhost/test/'
  end
  object btnCheck: TButton
    Left = 160
    Top = 168
    Width = 97
    Height = 25
    Caption = 'Check Updates'
    TabOrder = 1
    OnClick = btnCheckClick
  end
  object edtLocal: TEdit
    Left = 184
    Top = 56
    Width = 537
    Height = 21
    TabOrder = 2
  end
end
