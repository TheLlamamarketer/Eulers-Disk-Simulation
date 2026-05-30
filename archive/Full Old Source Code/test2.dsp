# Microsoft Developer Studio Project File - Name="test2" - Package Owner=<4>
# Microsoft Developer Studio Generated Build File, Format Version 6.00
# ** DO NOT EDIT **

# TARGTYPE "Win32 (x86) Console Application" 0x0103

CFG=test2 - Win32 Debug
!MESSAGE This is not a valid makefile. To build this project using NMAKE,
!MESSAGE use the Export Makefile command and run
!MESSAGE 
!MESSAGE NMAKE /f "test2.mak".
!MESSAGE 
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "test2.mak" CFG="test2 - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "test2 - Win32 Release" (based on "Win32 (x86) Console Application")
!MESSAGE "test2 - Win32 Debug" (based on "Win32 (x86) Console Application")
!MESSAGE 

# Begin Project
# PROP AllowPerConfigDependencies 0
# PROP Scc_ProjName ""
# PROP Scc_LocalPath ""
CPP=cl.exe
F90=df.exe
RSC=rc.exe

!IF  "$(CFG)" == "test2 - Win32 Release"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "Release"
# PROP BASE Intermediate_Dir "Release"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "Release"
# PROP Intermediate_Dir "Release"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE F90 /compile_only /nologo /warn:nofileopt
# ADD F90 /compile_only /nologo /warn:nofileopt
# ADD BASE CPP /nologo /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_CONSOLE" /D "_MBCS" /YX /FD /c
# ADD CPP /nologo /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_CONSOLE" /D "_MBCS" /YX /FD /c
# ADD BASE RSC /l 0x424 /d "NDEBUG"
# ADD RSC /l 0x424 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:console /machine:I386
# ADD LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib f90GL.lib f90GLU.lib f90GLUT.lib glut32.lib /nologo /subsystem:console /machine:I386 /nodefaultlib:"libc.lib"

!ELSEIF  "$(CFG)" == "test2 - Win32 Debug"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Debug"
# PROP BASE Intermediate_Dir "Debug"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "Debug"
# PROP Intermediate_Dir "Debug"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE F90 /check:bounds /compile_only /dbglibs /debug:full /nologo /traceback /warn:argument_checking /warn:nofileopt
# ADD F90 /check:bounds /compile_only /dbglibs /debug:full /nologo /traceback /warn:argument_checking /warn:nofileopt
# ADD BASE CPP /nologo /W3 /Gm /GX /ZI /Od /D "WIN32" /D "_DEBUG" /D "_CONSOLE" /D "_MBCS" /YX /FD /GZ /c
# ADD CPP /nologo /W3 /Gm /GX /ZI /Od /D "WIN32" /D "_DEBUG" /D "_CONSOLE" /D "_MBCS" /YX /FD /GZ /c
# ADD BASE RSC /l 0x424 /d "_DEBUG"
# ADD RSC /l 0x424 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:console /debug /machine:I386 /pdbtype:sept
# ADD LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib f90GL.lib f90GLU.lib f90GLUT.lib glut32.lib /nologo /subsystem:console /incremental:no /debug /machine:I386 /nodefaultlib:"libc.lib" /out:"Debug/edisk.exe" /pdbtype:sept

!ENDIF 

# Begin Target

# Name "test2 - Win32 Release"
# Name "test2 - Win32 Debug"
# Begin Group "Source Files"

# PROP Default_Filter "cpp;c;cxx;rc;def;r;odl;idl;hpj;bat;f90;for;f;fpp"
# Begin Source File

SOURCE=.\model2\cdata.f90
# End Source File
# Begin Source File

SOURCE=.\hairer\cdopri.for
# End Source File
# Begin Source File

SOURCE=.\hairer\contd5.for
# End Source File
# Begin Source File

SOURCE=.\hairer\contd8.for
# End Source File
# Begin Source File

SOURCE=.\model2\disk.f90
DEP_F90_DISK_=\
	".\Debug\cdata.mod"\
	".\Debug\disk_data.mod"\
	
# End Source File
# Begin Source File

SOURCE=.\model2\disk0.f90
DEP_F90_DISK0=\
	".\Debug\cdata.mod"\
	".\Debug\disk_data.mod"\
	
# End Source File
# Begin Source File

SOURCE=.\model2\disk_data.f90
# End Source File
# Begin Source File

SOURCE=.\hairer\dop853.for
# End Source File
# Begin Source File

SOURCE=.\hairer\dopcor.for
# End Source File
# Begin Source File

SOURCE=.\hairer\dopri5.for
# End Source File
# Begin Source File

SOURCE=.\hairer\dp86co.for
# End Source File
# Begin Source File

SOURCE=.\hairer\hinit.for
# End Source File
# Begin Source File

SOURCE=.\model2\input.f90
DEP_F90_INPUT=\
	".\Debug\disk_data.mod"\
	".\Debug\mui.mod"\
	
# End Source File
# Begin Source File

SOURCE=.\model2\integ.f90
DEP_F90_INTEG=\
	".\Debug\disk_data.mod"\
	
# End Source File
# Begin Source File

SOURCE=.\model2\main.f90
DEP_F90_MAIN_=\
	".\Debug\disk_data.mod"\
	".\Debug\mui.mod"\
	
# End Source File
# Begin Source File

SOURCE=.\screen\mcalc.f90
# End Source File
# Begin Source File

SOURCE=.\screen\mchr.f90
# End Source File
# Begin Source File

SOURCE=.\screen\mio.f90
# End Source File
# Begin Source File

SOURCE=.\screen\mn2c.f90
# End Source File
# Begin Source File

SOURCE=.\screen\mui.f90
DEP_F90_MUI_F=\
	".\Debug\mcalc.mod"\
	".\Debug\mchr.mod"\
	".\Debug\mio.mod"\
	".\Debug\mn2c.mod"\
	
# End Source File
# Begin Source File

SOURCE=.\graphics\my_animation.f90
DEP_F90_MY_AN=\
	".\Debug\my_disk.mod"\
	".\Debug\my_view_modifier.mod"\
	{$(INCLUDE)}"opengl_glut.mod"\
	
# End Source File
# Begin Source File

SOURCE=.\graphics\my_disk.f90
DEP_F90_MY_DI=\
	".\Debug\disk_data.mod"\
	".\Debug\my_primitives.mod"\
	".\Debug\my_view_modifier.mod"\
	{$(INCLUDE)}"opengl_gl.mod"\
	{$(INCLUDE)}"opengl_glu.mod"\
	{$(INCLUDE)}"opengl_glut.mod"\
	
# End Source File
# Begin Source File

SOURCE=.\graphics\my_primitives.f90
DEP_F90_MY_PR=\
	{$(INCLUDE)}"opengl_gl.mod"\
	{$(INCLUDE)}"opengl_glu.mod"\
	{$(INCLUDE)}"opengl_glut.mod"\
	
# End Source File
# Begin Source File

SOURCE=.\graphics\my_viev_modifier.f90
DEP_F90_MY_VI=\
	{$(INCLUDE)}"opengl_gl.mod"\
	{$(INCLUDE)}"opengl_glu.mod"\
	{$(INCLUDE)}"opengl_glut.mod"\
	
# End Source File
# Begin Source File

SOURCE=.\model2\post.f90
DEP_F90_POST_=\
	".\Debug\disk_data.mod"\
	
# End Source File
# Begin Source File

SOURCE=.\model2\prop.f
# End Source File
# Begin Source File

SOURCE=.\model2\solout.f90
DEP_F90_SOLOU=\
	".\Debug\cdata.mod"\
	".\Debug\disk_data.mod"\
	
# End Source File
# Begin Source File

SOURCE=.\zeroin.f
# End Source File
# Begin Source File

SOURCE=.\model2\ztime.f90
DEP_F90_ZTIME=\
	".\Debug\cdata.mod"\
	
# End Source File
# End Group
# Begin Group "Header Files"

# PROP Default_Filter "h;hpp;hxx;hm;inl;fi;fd"
# End Group
# Begin Group "Resource Files"

# PROP Default_Filter "ico;cur;bmp;dlg;rc2;rct;bin;rgs;gif;jpg;jpeg;jpe"
# End Group
# End Target
# End Project
