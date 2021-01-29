function Get-Content($name, $packagePath)
{
  [string]$nugetPackageRoot = $env:NUGET_PACKAGES
  if ($nugetPackageRoot -eq "")
  {
    $nugetPackageRoot = Join-Path $env:USERPROFILE ".nuget\packages"
  }

  $realPackagePath = Join-Path $nugetPackageRoot $packagePath 
  $resourceTypeName = $name + "Resources"

  $targetsContent = @"
  <Project>
      <ItemGroup>
        <Compile Include="..\Shared\ResourceLoader.cs" Link="ResourceLoader.cs" />
      </ItemGroup>

      <ItemGroup>

"@;

  $codeContent = @"
  // This is a generated file, please edit Generate.ps1 to change the contents

  using System.Collections.Generic;
  using Microsoft.CodeAnalysis;

  namespace DotNet.Reference.Assemblies
  {

"@;

  $codeContent += @"
    internal static class $resourceTypeName
    {

"@;

  $refContent = @"
    public static class $name
    {

"@

  $name = $name.ToLower()
  $list = Get-ChildItem -filter *.dll $realPackagePath | %{ $_.FullName }
  $allPropNames = @()
  foreach ($dllPath in $list)
  {
    $dllName= Split-Path -Leaf $dllPath
    $dll = $dllName.Substring(0, $dllName.Length - 4)
    $logicalName = "$($name).$($dll)";
    $dllPath = $dllPath.Substring($nugetPackageRoot.Length)
    $dllPath = '$(NuGetPackageRoot)' + $dllPath

    $targetsContent += @"
        <EmbeddedResource Include="$dllPath">
          <LogicalName>$logicalName</LogicalName>
          <Link>Resources\$name\$dllName</Link>
        </EmbeddedResource>

"@

    $propName = $dll.Replace(".", "");
    $allPropNames += $propName
    $fieldName = "_" + $propName
    $codeContent += @"
        private static byte[]? $fieldName;
        internal static byte[] $propName => ResourceLoader.GetOrCreateResource(ref $fieldName, "$logicalName");

"@

    $refContent += @"
        public static PortableExecutableReference $propName { get; } = AssemblyMetadata.CreateFromImage($($resourceTypeName).$($propName)).GetReference(display: "$dll ($name)");

"@

  }

  $refContent += @"
        public static IEnumerable<PortableExecutableReference> All { get; }= new PortableExecutableReference[]
        {

"@;
    foreach ($propName in $allPropNames)
    {
      $refContent += @"
            $propName,

"@
    }

    $refContent += @"
        };
    }

"@

    $codeContent += @"
    }

"@
    $codeContent += $refContent;

  $targetsContent += @"
    </ItemGroup>
  </Project>
"@;

  $codeContent += @"
}
"@

  return @{ CodeContent = $codeContent; TargetsContent = $targetsContent}
}

# NetCoreApp31 
$map = Get-Content "NetCoreApp31" 'Microsoft.NETCore.App.Ref\3.1.0\ref\netcoreapp3.1' 
$targetDir = Join-Path $PSScriptRoot "..\DotNet.Reference.Assemblies.NetCoreApp31"
$map.CodeContent | Out-File (Join-Path $targetDir "Generated.cs") -Encoding Utf8
$map.TargetsContent | Out-File (Join-Path $targetDir "Generated.targets") -Encoding Utf8


#dd-TargetFramework "NetStandard20" 'netstandard.library\2.0.3\build\netstandard2.0\ref'