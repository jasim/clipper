/*============================================================================

   (c) 1993  TECHNO SOFTWARE CORPORATION

   This module contains information proprietary to TECHNO SOFTWARE
   CORPORATION, and should be treated confidential.

   it310008.prg - Inventory Register module
             for Inventory Tracking System (ITS)

   acr / 05.17.93

 Revisions :
  1. Advance the printing of total no. of days in the days columns in
     FUNCTION it31000802.
                     atc / 07.16.93
                     
  2. Replaced prow() with nCtr 
                     eso / 09.24.95                  

============================================================================*/
#include "Janus.ch"
#include "its.ch"
#include "set.ch"
#include "setcurs.ch"
#include "inkey.ch"

#define RPT_ID   "I-REG-D"

//jzo05-19-98 #define RPT_NAME "INVENTORY REGISTER"
#define RPT_NAME "STOCK AGING REPORT"

#define THIS_WIDTH (127 + PLU_DESC_LEN +LEFT_MARGIN +PLU_CODE_LEN)

memvar nUnit, getlist


STATIC pttl[2], gttl[2]
STATIC nPage := 0, nTCost := 0, footer_now := 0, days_old := 0
static nCtr := 0, flag:=.f., sdate


/*=====================================================*/
 FUNCTION it310008
/*=====================================================*/
   LOCAL cOldClr := setcolor ( BN_COLOR ), nOldCursor := 0
   local nGoPrint := 2, vbrowse

   sdate := date()
   SET CURSOR ON
   vBrowse := OpenWindow(10,30,12,50)
   @ 10,35 say "REPORT DATE"
   @ 11,33 say "Date: "Get sdate
   read
   if lastkey() == K_ESC
      SET CURSOR OFF
      CloseWindow(vBrowse)
      return nil
   endif   
   SET CURSOR OFF
   CloseWindow(vBrowse)

   afill ( pttl, 0 )
   afill ( gttl, 0 )

   nOldCursor = setcursor ( SC_NONE )

   // Create display window.
   window ( 19, 1, 22, 60, CONFIRM_COLOR )
   @ 1, 1 wsay " Creating " + RPT_NAME + ".  Please wait ..."

   if NetUse("UNIT",DB_SHARED,NUM_SECONDS)
      set Index to UNIT
   endif  
   if UNIT->(DbSeek(padl(alltrim(str(nUnit)),3,"0"))) 
      Set(_SET_PATH,UNIT->UNIT_PATH)
   endif   
   if NetUse("UITEMS",DB_SHARED,NUM_SECONDS)
      Set Index to UITEMS
   endif   

   if NetUse("ITEM.DBF",DB_SHARED,NUM_SECONDS)
   //  Set index to I_001
    index on ITEM->I_020 to indr
   endif

   if NetUse("V",DB_SHARED,NUM_SECONDS)
      Set index to V_001
   endif
   if NetUse("RR",DB_SHARED,NUM_SECONDS)
      Set index to RR_001
   endif 
   if NetUse("RR_ITEMS",DB_SHARED,NUM_SECONDS)
      Set index to RRI_LINK
   endif


//   set filter to ITEM->I_019 != 2 // rEVISED atc 07-21-93.
   ITEM->(DbGoTop())


#ifdef TO_FILE
   set printer to ".\"+RPT_ID
#endif

   set device to printer
   set printer on
   set console off
   
   // Standard page header routine.
   it390003 ( SYS_NAME, RPT_NAME, THIS_WIDTH, LEFT_MARGIN, RIGHT_MARGIN )
   nCtr := 1
   nPage := 1

   // Print the headers for this report.
   it31000801()   
   
   do while V->(!Eof())


      // Indicate record being processed.
      @ 2, 1 wsay " Item: " + V->V_001

      // Print on next row.
       ? MARGIN + V->V_001  
      ?? space(2) + V->V_002 
      nCtr += 1
      
     flag := .f.
     ITEM->(DbSeek(V->V_001))
     while ITEM->(!Eof()) .and. V->V_001 == ITEM->I_020
      IF ITEM->(!Deleted()) .and. UITEMS->(DbSeek(ITEM->I_001))
       if UITEMS->UI_STK_BAL <> 0
         if flag
            ? MARGIN + space(35)
            nCtr += 1
         endif     
         ?? space(2) + ITEM->I_001 
         ?? space(2) + ITEM->I_002 
         ?? space(2) + tran(UITEMS->UI_STK_BAL, "999,999,999" )
         ?? space(2) + ITEM->I_005 
         ?? space(2) + tran(ITEM->I_007, "99,999.99" )
         ?? space(2) + tran(ITEM->I_003, "99,999.99" )
         nTCost = ITEM->i_007 * (UITEMS->UI_STK_BAL)
         ?? space(2) + tran(nTCost, "999,999,999.99" )
         IF nUnit != 0 
            UITEMS->(RecLock(0))
            UITEMS->UI_DATEREC := ITEM->I_014
            UITEMS->(DbUnlock())
         ENDIF   
         ?? space(3) + dtoc(UITEMS->UI_DATEREC )
         days_old = date() - UITEMS->UI_DATEREC
         ?? space(4) + tran( days_old, "999,999" )

         // Accumulate the page and grand total and count.
         it31000803()
         flag := .t.
         if ITEM->(!eof()) .and. nCtr == 55
               it31000802()
               nCtr := 0
               it390006 ( RPT_ID, THIS_WIDTH, LEFT_MARGIN, RIGHT_MARGIN, nPage )
               npage += 1                              
               eject
               it390003 ( SYS_NAME, RPT_NAME, THIS_WIDTH, LEFT_MARGIN, RIGHT_MARGIN )
               nCtr := 1   
               it31000801()
          endif   
       ENDIF  
      ENDIF 
      ITEM->(DbSkip())
    enddo  
    V->(DbSkip())
   enddo

   // Print the page totals.
   it31000802()

    ? MARGIN + "END OF REPORT" + replicate ( "=", THIS_WIDTH - LEFT_MARGIN - 13) 
   it390006 ( RPT_ID, THIS_WIDTH, LEFT_MARGIN, RIGHT_MARGIN, nPage )
   eject

   dbCloseAll()

   set device to screen
   set printer off
   set console on
   set cursor on
   set printer to

   // Remove window.
   killwindow()
   tone ( 2100, 3 )

   // Restore cursor shape.
   setcursor ( nOldCursor )

   // Restore color set.
   setcolor ( cOldClr )

   // Screen or Printed Reports.

   RepGen( ".\"+RPT_ID, RPT_NAME, 2, 214 )
   ferase("indr.ntx")
RETURN NIL


/*=====================================================*/
 FUNCTION it310008p
/*=====================================================*/
   LOCAL cOldClr := setcolor ( BN_COLOR ), nOldCursor := 0
   local nGoPrint := 2, getlist :={}, vRecord := space(3), vBrowse   

   sdate := date()
   SET CURSOR ON
   vBrowse := OpenWindow(10,30,12,50)
   @ 10,35 say "REPORT DATE"
   @ 11,33 say "Date: "Get sdate
   read
   if lastkey() == K_ESC
      SET CURSOR OFF
      CloseWindow(vBrowse)
      return nil
   endif   
   SET CURSOR OFF
   CloseWindow(vBrowse)

   vBrowse := OpenWindow(15,30,17,50)
   @ 16,31 say "Supplier Code: "Get vRecord Pict "999"
   setCursor("ON")
   read
   setCursor("OFF")
   CloseWindow(vBrowse)

   vRecord := padl(alltrim(vRecord),3,"0")


   afill ( pttl, 0 )
   afill ( gttl, 0 )

   nOldCursor = setcursor ( SC_NONE )

   // Create display window.
   window ( 19, 1, 22, 60, CONFIRM_COLOR )
   @ 1, 1 wsay " Creating " + RPT_NAME + ".  Please wait ..."

   if NetUse("UNIT",DB_SHARED,NUM_SECONDS)
      set Index to UNIT
   endif  
   if UNIT->(DbSeek(padl(alltrim(str(nUnit)),3,"0"))) 
      Set(_SET_PATH,UNIT->UNIT_PATH)
   endif   
   if NetUse("UITEMS",DB_SHARED,NUM_SECONDS)
      Set Index to UITEMS
   endif   

   if NetUse("ITEM.DBF",DB_SHARED,NUM_SECONDS)
    //  Set index to I_001
    index on ITEM->I_020 to indr
   endif

   if NetUse("V",DB_SHARED,NUM_SECONDS)
      Set index to V_001
   endif
   
   if NetUse("RR",DB_SHARED,NUM_SECONDS)
      Set index to RR_001
   endif 
   if NetUse("RR_ITEMS",DB_SHARED,NUM_SECONDS)
      Set index to RRI_LINK
   endif
   
//   set filter to ITEM->I_019 != 2 // rEVISED atc 07-21-93.
   ITEM->(DbGoTop())

#ifdef TO_FILE
   set printer to ".\"+RPT_ID
#endif

   set device to printer
   set printer on
   set console off
   
   // Standard page header routine.
   it390003 ( SYS_NAME, RPT_NAME, THIS_WIDTH, LEFT_MARGIN, RIGHT_MARGIN )
   nCtr := 1
   nPage := 1

   // Print the headers for this report.
   it31000801()   

  flag := .f.    
  if ITEM->(DbSeek(vRecord))  

      // Indicate record being processed.
       @ 2, 1 wsay " Item: " + vRecord

      // Print on next row.
     if V->(DbSeek(ITEM->I_020)) 
       ? MARGIN + V->V_001  
      ?? space(2) + V->V_002
      nctr += 1
     endif  

     while ITEM->(!Eof()) .and. vRecord == ITEM->I_020
      IF ITEM->(!Deleted()) .and. UITEMS->(DbSeek(ITEM->I_001))
       if UITEMS->UI_STK_BAL <> 0
         if flag
            ? MARGIN + space(35)
            nCtr += 1
         endif     
         ?? space(2) + ITEM->I_001 
         ?? space(2) + ITEM->I_002 
         ?? space(2) + tran(UITEMS->UI_STK_BAL, "999,999,999" )
         ?? space(2) + ITEM->I_005 
         ?? space(2) + tran(ITEM->I_007, "99,999.99" )
         ?? space(2) + tran(ITEM->I_003, "99,999.99" )
         nTCost = ITEM->i_007 * (UITEMS->UI_STK_BAL)
         ?? space(2) + tran(nTCost, "999,999,999.99" )
         IF nUnit != 0
            UITEMS->(RecLock(0))
            UITEMS->UI_DATEREC := ITEM->I_014
            UITEMS->(DbUnlock())
         ENDIF   

         ?? space(3) + dtoc(UITEMS->UI_DATEREC )
         days_old = date() - UITEMS->UI_DATEREC
         ?? space(4) + tran( days_old, "999,999" )

         // Accumulate the page and grand total and count.
         it31000803()
         flag := .t.
          if ITEM->(!eof()) .and. nCtr == 55
               it31000802()
               nCtr := 0
               it390006 ( RPT_ID, THIS_WIDTH, LEFT_MARGIN, RIGHT_MARGIN, nPage )
               npage += 1                              
               eject
               it390003 ( SYS_NAME, RPT_NAME, THIS_WIDTH, LEFT_MARGIN, RIGHT_MARGIN )
               nCtr := 1   
               it31000801()
          endif   
       ENDIF  
      ENDIF 
      ITEM->(DbSkip())
     enddo
   else
      Message("Supplier Code :"+vRecord+" not found ...")
      BUMMER()
   endif

     
   // Print the page totals.
   it31000802()

    ? MARGIN + "END OF REPORT" + replicate ( "=", THIS_WIDTH - LEFT_MARGIN - 13) 
   it390006 ( RPT_ID, THIS_WIDTH, LEFT_MARGIN, RIGHT_MARGIN, nPage )
   eject

   dbCloseAll()

   set device to screen
   set printer off
   set console on
   set cursor on
   set printer to

   // Remove window.
   killwindow()
   tone ( 2100, 3 )

   // Restore cursor shape.
   setcursor ( nOldCursor )

   // Restore color set.
   setcolor ( cOldClr )

   // Screen or Printed Reports.
   RepGen( ".\"+RPT_ID, RPT_NAME, 2, 214 )
   ferase("indr.ntx")
RETURN NIL


/*============================================================================
   Page Header
============================================================================*/
STATIC FUNCTION it31000801

       
       ? MARGIN + "Report Date: As of  " + dtoc(SDate)
       ?? space(94) + "UNIT " +  padl(alltrim(str(nUnit)),3,"0")
       ? MARGIN + "Supplier------------------------------"
      ?? space(0) + "Item--------------------------------------------------------------------------" 
      ?? repl("-",PLU_DESC_LEN+PLU_CODE_LEN+11) 

       ? MARGIN   + padr ( "Code", 4 )
      ?? space(2) + padr ( "Name", 30) 
      ?? space(2) + padr ( "Code", PLU_CODE_LEN )
      ?? space(2) + padr ( "Description",   PLU_DESC_LEN )
      ?? space(2) + padl ( "Qty on Hand",   11 )
      ?? space(2) + padr ( "Unit",       10 )
      ?? space(2) + padl ( "Unit Cost",  9 )
      ?? space(2) + padl ( "Sell Prce",  9 )
      ?? space(2) + padl ( "Total Cost",    14 )
      ?? space(2) + padr ( "Date Rcvd",     10 )
      ?? space(2) + padl ( "Days Old",       8 )

       ? MARGIN + repl( "-", THIS_WIDTH - LEFT_MARGIN)
      nCtr += 4 
RETURN NIL

/*============================================================================
============================================================================*/
STATIC FUNCTION it31000802

    ? MARGIN + replicate ( "-", THIS_WIDTH - LEFT_MARGIN)
    ? MARGIN + "   PAGE TOTAL" 
   ?? space((PLU_CODE_LEN-12)+3+PLU_DESC_LEN + 37) + tran( pttl[1], "999,999,999" )
  // ?? space(56) + tran( pttl[2], "999,999" ) 

    ? MARGIN + "RUNNING TOTAL" 
   ?? space((PLU_CODE_LEN-12)+3+PLU_DESC_LEN + 37) + tran( gttl[1], "999,999,999" )
  // ?? space(56) + tran( gttl[2], "999,999" ) 
   ? MARGIN + replicate ( "-", THIS_WIDTH - LEFT_MARGIN)
   
   afill (pttl, 0 )
   nCtr += 4

RETURN NIL

/*============================================================================
============================================================================*/
STATIC FUNCTION it31000803

   // Accumulate quantity / amount pairs.
   pttl[1] += UITEMS->UI_STK_BAL
   pttl[2] += days_old

   gttl[1] += UITEMS->UI_STK_BAL
   gttl[2] += days_old

RETURN NIL

