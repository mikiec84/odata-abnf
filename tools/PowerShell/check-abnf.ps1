<# 
.SYNOPSIS
    Unit test for OData ABNF grammar

.DESCRIPTION
    This script compiles the three OData ABNF files into a parser using the Java APG fork from https://github.com/ralfhandl/apg-java

    It then executes all tests in the three testcase files using the parser and the ABNF test tools from https://github.com/SAP/abnf-test-tool

    Prerequisites 
    - Java SDK         http://jdk.java.net
    - Git              https://git-scm.com/download/win 
    - Java APG         https://github.com/ralfhandl/apg-java
    - ABNF test tool   https://github.com/SAP/abnf-test-tool
#>

if ((Get-Command "javac.exe" -ErrorAction SilentlyContinue) -eq $null) { echo "Cannot find javac.exe in PATH, please install a Java SE JDK"; exit 1 }
if ((Get-Command "java.exe"  -ErrorAction SilentlyContinue) -eq $null) { echo "Cannot find java.exe in PATH, please install a Java SE JDK"; exit 1 }


# check for apg.jar, make it if missing
if ( !(Test-Path "../../../apg-java/build/apg.jar") ) { 
    if ((Get-Command "git.exe"   -ErrorAction SilentlyContinue) -eq $null) { echo "Cannot find git.exe in PATH, please install Git"; exit 1 }
    if ((Get-Command "jar.exe"   -ErrorAction SilentlyContinue) -eq $null) { echo "Cannot find jar.exe in PATH, please install a Java SE JDK"; exit 1 }

    pushd "../../.."
    echo "make apg.jar"

    if ( !(Test-Path "apg-java") ) {
        git clone https://github.com/ralfhandl/apg-java
        if (!$?) { popd; echo "Could not clone apg-java"; exit 1 }
    }

    cd "apg-java"
    if ( !(Test-Path "bin") ) { md "bin" >$null }
    javac -d bin src/apg/*.java
    if (!$?) { popd; echo "Could not compile apg-java"; exit 1 }

    cd "build"
    jar cmf apg.mf apg.jar -C ../bin .
    if (!$?) { popd; echo "Could not create apg.jar"; exit 1 }

    popd
}

# check for abnf-test-tool.jar, build it if missing
if ( !(Test-Path "../../../abnf-test-tool/build/abnf-test-tool.jar") ) { 
    if ((Get-Command "git.exe"   -ErrorAction SilentlyContinue) -eq $null) { echo "Cannot find git.exe in PATH, please install Git"; exit 1 }
    if ((Get-Command "jar.exe"   -ErrorAction SilentlyContinue) -eq $null) { echo "Cannot find jar.exe in PATH, please install a Java SE JDK"; exit 1 }

    pushd "../../.."
    echo "make abnf-test-tool.jar"

    if ( !(Test-Path "abnf-test-tool") ) {
        git clone https://github.com/SAP/abnf-test-tool
        if (!$?) { popd; echo "Could not clone abnf-test-tool"; exit 1 }
    }

    cd "abnf-test-tool"
    if ( !(Test-Path "bin") ) { md "bin" >$null }
    javac -cp ../apg-java/build/apg.jar -d bin src/checker/*.java
    if (!$?) { popd; echo "Could not compile abnf-test-tool"; exit 1 }

    cd "build"
    jar cmf abnf-test-tool.mf abnf-test-tool.jar -C ../bin checker
    if (!$?) { popd; echo "Could not create abnf-test-tool.jar"; exit 1 }

    popd
}

# generate parser for ABNF
if ( !(Test-Path "grammar") ) { md "grammar" >$null }

if ( !(Test-Path "grammar/GrammarUnderTest.java") -or
     (get-item "grammar/GrammarUnderTest.java").LastWriteTime -lt (get-item "../../abnf/odata-abnf-construction-rules.txt").LastWriteTime -or 
     (get-item "grammar/GrammarUnderTest.java").LastWriteTime -lt (get-item "../../abnf/odata-aggregation-abnf.txt").LastWriteTime -or
     (get-item "grammar/GrammarUnderTest.java").LastWriteTime -lt (get-item "../../abnf/odata-temporal-abnf.txt").LastWriteTime ) {

	echo "Compiling ABNF..."

	rm grammar/GrammarUnderTest*

	java.exe -cp ../../../apg-java/build/apg.jar apg/Generator /in=../../../abnf/odata-abnf-construction-rules.txt /in=../../../abnf/odata-aggregation-abnf.txt /in=../../../abnf/odata-temporal-abnf.txt /package=grammar /java=GrammarUnderTest /dir=grammar/ /dv >grammar/apg.log

    select-string -pattern "^\*\*\* java.lang.Error|^line" -casesensitive -path grammar/apg.log | select -exp line

    if ( !(Test-Path "grammar/GrammarUnderTest.java") ) { exit 1 }
}

# compile parser
if ( !(Test-Path "grammar/GrammarUnderTest.class") -or
     (get-item "grammar/GrammarUnderTest.java").LastWriteTime -gt (get-item "grammar/GrammarUnderTest.class").LastWriteTime ) {

    javac.exe -cp ../../../apg-java/build/apg.jar grammar/GrammarUnderTest.java
    if (!$?) { exit 1 }
}

# run tests	
java.exe -cp "../../../apg-java/build/apg.jar;../../../abnf-test-tool/build/abnf-test-tool.jar;." checker.Check ../../abnf/odata-abnf-testcases.xml ../../abnf/odata-aggregation-testcases.xml ../../abnf/odata-temporal-testcases.xml