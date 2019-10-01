Using Namespace System.Management.Automation.Language

Find-Type -Namespace System.Management.Automation.Language | Where-Object Name -like '*Ast' | Measure-Object

Find-Type -InheritsType ("Ast" -as [Type]) | Measure-Object
  