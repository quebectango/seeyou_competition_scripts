Program Alt_Scoring_V3;

// Adapted from SC3A_scoring, Version 8.00, Date 26.06.2019
// Initial revisions by Thomas Pressley, Thomas.Pressley@ttuhsc.edu
// Initial coding, 19.04.2021
// 08.05.2021  Revised to exclude noncompeting pilots from calculation of median provisional score
//             Revised to report 200/(Spo-Spm) rather than ProvScoreDiff in Info3; the latter was not self-explanatory
// 11.05.2021 Revised to take account of Rule 8.4.1b and max (Pv,Pd)

// Questions or items likely to be editted are marked by "****"

const UseHandicaps = 2;   // set to: 0 to disable handicapping, 1 to use handicaps, 2 is auto (handicaps only for club and multi-seat)

type
  TDoubleArray = array of double;                         // Define the array needed for ProvScoreList (see below)

var
  // Most definitions are those in the rules

  // Championship Day variables
  Dm, D1,                                                 // Minimum distances required for a given task
  n1, n3, N, D0, Vo, T0, Hmin,                            // Hmin is Ho in the rules.  D0 and T0 are Do and To in the rules (avoids conflict with coding operators)
  Pm, Pn, F, Fcr, Day: Double;                            // What is Pn?   ****

  // Competitor variables
  D, H, Dh, M, T, Dc, Pd, V, Vh, Pv, Sp, S, Spo, Spm : double;      // What is M and Dc?    ****
  
  PmaxDistance, PmaxTime : double;                        // Components used to calculate Pm, the maximal available score before applying factors
  ProvScoreList : TDoubleArray;                           // List of nonzero provisional scores 
  ProvScoreDiff : double;                                 // Used in "Score of the Day" calculation, 200/(Spo - Spm) 

  i,j : integer;
  str : String;
  Interval, NumIntervals, GateIntervalPos, NumIntervalsPos, PilotStartInterval, PilotStartTime, PilotPEVStartTime, StartTimeBuffer : Integer;
  AAT : boolean;
  Auto_Hcaps_on : boolean;
  Median_Correction : boolean;                            // True if median provisional score is needed for "Score of the Day"

procedure bubbleSort(var list: TDoubleArray);
// Sorts a list in ascending order

  var
     a, b, z: integer;
     q: double;

  begin
     z := GetArrayLength(list)-1;
     for a := z downto 2 do
     for b := 1 to a - 1 do
        if list[b] > list[b + 1] then
          begin
             q := list[b];
             list[b] := list[b + 1];
             list[b + 1] := q;
          end;
  end;

Function MinValue( a,b,c : double ) : double;
// Given a triplet of numbers, the function returns the minimum

  var m : double;

  begin
    m := a;
    If b < m Then m := b;
    If c < m Then m := c;
    MinValue := m;
  end;

function Median(aArray: TDoubleArray): double;
// Returns the median of an ordered list
              
  var
    MiddleIndex: integer;

  begin
    bubbleSort(aArray);
    MiddleIndex := ((high(aArray) - low(aArray)) div 2) + 1;
    M := MiddleIndex;
    Dc := GetArrayLength(aArray);
    if Round(GetArrayLength(aArray) / 2) = GetArrayLength(aArray) / 2 then
      Median := (aArray[MiddleIndex + 1] + aArray[MiddleIndex]) / 2 
    else
      Median := aArray[MiddleIndex];
  end;

begin

  // initial checks
  if GetArrayLength(Pilots) <= 1 then                              // Sanity check !  Useless to execute scoring program if there are no competitors
    exit;

  if (UseHandicaps < 0) OR (UseHandicaps > 2) then                 // Insure that we have a valid handicap option (set in const definition above)
  begin
    Info1 := '';
    Info2 := 'ERROR: constant UseHandicaps is set wrong';
    exit;
  end;

  If Task.TaskTime = 0 then                                        // Task.TaskTime: Integer; task time in seconds; a zero value implies a racing task rather than an assigned area task 
    AAT := false
  else
    AAT := true;

  If (AAT = true) AND (Task.TaskTime < 1800) then                  // Apparently this is somewhat arbitrary, but if the minimum task time is less than 30 minutes, report the apparent error and exit
  begin
    Info1 := '';
    Info2 := 'ERROR: Incorrect Task Time';
    exit;
  end;

  // Task.ClassID: string
  // Define the Minimum Distance to validate the Day, depending on the class [meters]
  Dm := 100000;                                                    // Default to 100 km if an unknown class
  if Task.ClassID = 'club' Then Dm := 100000;
  if Task.ClassID = '13_5_meter' Then Dm := 100000;
  if Task.ClassID = 'standard' Then Dm := 120000;
  if Task.ClassID = '15_meter' Then Dm := 120000;
  if Task.ClassID = 'double_seater' Then Dm := 120000;
  if Task.ClassID = '18_meter' Then Dm := 140000;
  if Task.ClassID = 'open' Then Dm := 140000;
  
  // Define the Minimum distance for 1000 points, depending on the class [meters]
  D1 := 250000;                                                    // Default to 250 km if an unknown class
  if Task.ClassID = 'club' Then D1 := 250000;
  if Task.ClassID = '13_5_meter' Then D1 := 250000;
  if Task.ClassID = 'standard' Then D1 := 300000;
  if Task.ClassID = '15_meter' Then D1 := 300000;
  if Task.ClassID = 'double_seater' Then D1 := 300000;
  if Task.ClassID = '18_meter' Then D1 := 350000;
  if Task.ClassID = 'open' Then D1 := 350000;

  // Handicaps for club and 20m multi-seat class
  Auto_Hcaps_on := false;                                         // Default to no handicaps until told otherwise
  if Task.ClassID = 'club' Then Auto_Hcaps_on := true;
  if Task.ClassID = 'double_seater' Then Auto_Hcaps_on := true;

  // DESIGNATED START PROCEDURE
  // This section was removed from the alternative scoring script, but it could be inserted here if needed.

  // Calculation of basic parameters

  // Initialize variables
  N := 0;             // Number of pilots who had a competition launch
  n1 := 0;            // Number of pilots with Marking distance greater than Dm - normally 100km; handicapped ?    ****
  Hmin := 100000;     // Lowest Handicap of all competitors in the class; it looks like original programmers have set this rediculously high to insure that it is reset    ****
  
  // Cycle through the list of pilots as flight records are submitted, and update Hmin, the lowest handicap of all the competitors in the class, as needed
  for i:=0 to GetArrayLength(Pilots)-1 do
    begin
      If UseHandicaps = 0 Then Pilots[i].Hcap := 1;
      If (UseHandicaps = 2) and (Auto_Hcaps_on = false) Then Pilots[i].Hcap := 1;

      // Pilots.isHC : boolean; true for competitors
      // Pilots.Hcap; pilot's handicap
      If not Pilots[i].isHC Then                   // Don't consider noncompeting pilots
        begin
           If Pilots[i].Hcap < Hmin Then Hmin := Pilots[i].Hcap; 
        end;
    end;

  // Sanity check !  Zero value for lowest handicap means something has gone wrong
  If Hmin=0 Then begin                             
       Info1 := '';
       Info2 := 'Error: Lowest handicap is zero!  Check pilot records.';
    Exit;
  end;

  // Cycle through the list of pilots as flight records are submitted, and update N and N1, the number of launches and the number of competitors achieving Dm, as needed
  for i:=0 to GetArrayLength(Pilots)-1 do
  begin
    If not Pilots[i].isHC Then                     // Don't consider noncompeting pilots; Pilots.isHC : boolean; true for competitors
       begin
         // Pilots.dis; distance in meters
         // Pilots.Hcap; pilot's handicap
         If Pilots[i].dis*Hmin/Pilots[i].Hcap >= Dm Then n1 := n1+1;
         // If Pilots[i].dis*Hmin/Pilots[i].Hcap >= ( Dm / 2.0) Then n4 := n4+1;  // Number of competitors who achieve a Handicapped Distance (Dh) of at least Dm/2; not needed for alternative scoring ?  ****
         // Pilots.takeoff; takeoff time in seconds; -1 if no start
         If Pilots[i].takeoff >= 0 Then N := N+1;
      end;
  end;

  // Sanity check !  Useless to execute scoring program if there are no competitors launched
  If N=0 Then begin
          Info1 := '';
	  Info2 := 'Warning: Number of competition pilots launched is zero';
  	Exit;
  end;
  
  // Initialize variables
  D0 := 0;
  T0 := 0;
  Vo := 0;

  // Cycle through the list of pilots as flight records are submitted, and update D0, T0, and Vo, as needed
  for i:=0 to GetArrayLength(Pilots)-1 do
  begin
    If not Pilots[i].isHC Then                   // Don't consider noncompeting pilots; Pilots.isHC : boolean; true for competitors
      begin
        // Find the highest corrected distance
        // Pilots.dis; distance in meters
        If Pilots[i].dis*Hmin/Pilots[i].Hcap > D0 Then D0 := Pilots[i].dis*Hmin/Pilots[i].Hcap;
      
        // Find the highest finisher's speed of the day and corresponding Task Time
        // Pilots.speed; pilot's speed in meters/second; -1 if no finish
        // Pilots.start; pilot's start time in seconds; -1 if no start
        // Pilots.finish; pilot's finish time in seconds; -1 if no finish

        If Pilots[i].speed*Hmin/Pilots[i].Hcap = Vo Then 
          // in case of a tie, lowest Task Time applies
          begin
            If (Pilots[i].finish-Pilots[i].start) < T0 Then
              begin
                Vo := Pilots[i].speed*Hmin/Pilots[i].Hcap;
                T0 := Pilots[i].finish-Pilots[i].start;
              end;
          end
      Else
        begin
          If Pilots[i].speed*Hmin/Pilots[i].Hcap > Vo Then
            begin
              Vo := Pilots[i].speed*Hmin/Pilots[i].Hcap;
              T0 := Pilots[i].finish-Pilots[i].start;
              If (AAT = true) and (T0 < Task.TaskTime) Then       // If marking time is shorter than Task time, Task time must be used for computations
                T0 := Task.TaskTime;
            end;
        end;
      end;
  end;

  // Sanity check !  Useless to execute scoring program if competitors achieved no distance
  If D0=0 Then begin
	  Info1 := '';
          Info2 := 'Warning: Longest handicapped distance is zero';
  	Exit;
  end;
  
  // Calculate maximum available points for the Day
  PmaxDistance := (1250 * (D0/D1)) - 250;
  PmaxTime := (400 * (T0/3600.0)) - 200;                          // Includes conversion from seconds to hours
  If T0 <= 0 Then PmaxTime := 1000;                               // I need to figure out why this line is needed !    ****
  Pm := MinValue( PmaxDistance, PmaxTime, 1000.0 );
  
  // Calculate Day Factor, F
  F := Pm/1000;
  
  // Determine number of finishers, regardless of speed
  n3 := 0;

  // Cycle through the list of pilots as flight records are submitted, and update n3 as needed
  for i:=0 to GetArrayLength(Pilots)-1 do
  begin
    If not Pilots[i].isHC Then                   // Don't consider noncompeting pilots; Pilots.isHC : boolean; true for competitors
      begin
        n3 := n3+1;
      end;
  end;
  
  // Calculate Completion Ratio Factor, Fcr
  Fcr := 1;
  If n1 > 0 then
    Fcr := (1.2 * (n3/n1)) + 0.6;
  If Fcr > 1 Then Fcr := 1;

  // Calculate the maximum provisional score, Spo
  Spo := F * Fcr * 1000; 

  // Initialize index for list of nonzero provisional scores
     j := 0;

  // Cycle through the list of pilots as flight records are submitted, and update Sp, the provisional score, as needed
  for i:=0 to GetArrayLength(Pilots)-1 do
    begin
      // For any finisher
      // Pilots.finish; pilot's finish time in seconds; -1 if no finish
      If Pilots[i].finish > 0 Then
        begin
          // Pilots.speed; pilot's speed in meters/second; -1 if no finish
          Pv := 1000 * ((Pilots[i].speed*Hmin)/Pilots[i].Hcap)/Vo;                 // Pv = 1000*(Vh/V0)
          // If Pilots[i].speed*Hmin/Pilots[i].Hcap < (2.0/3.0*Vo) Then Pv := 0; not needed for alternative scoring ?  ****
          Pd := 750 * ((Pilots[i].dis*Hmin)/Pilots[i].Hcap)/D0;                    // Pd = 750*(Dh/D0)
        end
    Else    //For any non-finisher
      begin
        Pv := 0;
        Pd := 750 * ((Pilots[i].dis*Hmin)/Pilots[i].Hcap)/D0;                      // Pd = 750*(Dh/D0)
      end;
    
    // Calculate pilot's provisional score
    // Pilots.Points; pilot's points, as shown in results; may be altered when calculating score for the day

    Pilots[i].Points := (F * Fcr * Pd);      // Initial calculation for a nonfinisher; Sp = F*Fcr*max(Pv,Pd)
    If Pv > Pd then
      Pilots[i].Points := (F * Fcr * Pv);    // Replace initial calculation for finisher because there will be speed points; an exception is a very slow finisher, when Pd is larger

  // Determine the length of a list of nonzero provisional scores

    If not Pilots[i].isHC then                   // Don't consider noncompeting pilots; Pilots.isHC : boolean; true for competitors
      If Pilots[i].Points > 0 then
         begin
             j := j + 1;                          // Increment length of nonzero provisional scores in list
        end;
  end;

  // Calculate the median provisional score

   SetArrayLength(ProvScoreList, j);
   j:= 0;

   // Cycle through the list of pilots as flight records are submitted and populate ProvScoreList with nonzero scores
   for i:=0 to GetArrayLength(Pilots)-1 do
     If not Pilots[i].isHC Then                   // Don't consider noncompeting pilots; Pilots.isHC : boolean; true for competitors
        begin
          If Pilots[i].Points > 0 then
            begin
              ProvScoreList[j] := Pilots[i].Points;
              j:= j + 1;
            end;
        end;

   Spm := 0.0; 
   Median_Correction := false;
   If GetArrayLength(ProvScoreList) > 3 then
       Spm := Median(ProvScoreList);            // Determine median provisional score once list is greater than 3 scores
   ProvScoreDiff := 200 / (Spo - Spm);

  // Determine if there is need to change the provisional score when calculating "Score for the Day"  
    if ProvScoreDiff < 1.0 then
      begin
        Median_Correction := true;     // ProvScoreDiff is relevant to calculating "Score of the Day"
        // Cycle through the list of pilots as flight records are submitted and calculate Score for the Day (without any penalties)
        for i:=0 to GetArrayLength(Pilots)-1 do
          begin
            Pilots[i].Points := Pilots[i].Points * ProvScoreDiff; 
          end;
      end;

   // Cycle through the list of pilots as flight records are submitted and determine the "Score for the Day"
   for i:=0 to GetArrayLength(Pilots)-1 do
     Pilots[i].Points := Round(Pilots[i].Points) - Round(Pilots[i].Penalty);
 
  // Data which is presented in the score-sheets
  // Cycle through the list of pilots as flight records are submitted, and update the parameters displayed in results, as needed
  // These do not appear to take into account any handicaps
  for i:=0 to GetArrayLength(Pilots)-1 do
    begin
      Pilots[i].sstart:=Pilots[i].start;
      Pilots[i].sfinish:=Pilots[i].finish;
      Pilots[i].sdis:=Pilots[i].dis;
      Pilots[i].sspeed:=Pilots[i].speed;
  end;
  
  // Info fields, also presented on the Score Sheets
  If AAT = true Then
    Info1 := 'Assigned Area Task, '
  else
    Info1 := 'Racing Task, ';

  Info1 := Info1 + 'Maximum Points: '+IntToStr(Round(Pm));
  Info1 := Info1 + ', F = '+FormatFloat('0.000',F);
  Info1 := Info1 + ', Fcr = '+FormatFloat('0.000',Fcr);
  // Info1 := Info1 + ', Max speed pts: '+IntToStr(Round(Pvm));  not needed for alternative scoring ?  ****

  If (n1/N) < 0.25 then
    Info1 := 'Day not valid - rule 8.2.1b';

  Info2 := 'Dm = ' + IntToStr(Round(Dm/1000.0)) + ' km';
  Info2 := Info2 + ', D1 = ' + IntToStr(Round(D1/1000.0)) + ' km';
  If (UseHandicaps = 0) or ((UseHandicaps = 2) and (Auto_Hcaps_on = false)) Then
    Info2 := Info2 + ', no handicaps'
  else
    Info2 := Info2 + ', handicapping enabled';

  // for debugging:
  Info3 := 'N: ' + IntToStr(Round(N));
  Info3 := Info3 + ', n1: ' + IntToStr(Round(n1));
  Info3 := Info3 + ', 200/(Spo-Spm): ' + FormatFloat('0.00',ProvScoreDiff);
  Info3 := Info3 + ', M: ' + IntToStr(Round(M));
  Info3 := Info3 + ', Spm: ' + FormatFloat('0.00',Spm);
  Info3 := Info3 + ', Do: ' + FormatFloat('0.00',D0/1000.0) + ' km';
  Info3 := Info3 + ', Vo: ' + FormatFloat('0.00',Vo*3.6) + ' km/h';
  If Median_Correction Then
    Info4 := Info4 + 'Use of Median Provisional Score in effect';

end.

