import "package:flutter/material.dart";
import "package:path_provider/path_provider.dart";
import "dart:convert";
import "dart:io";
import "dart:async";
import "dart:math";
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

PersistentData jobsInfoData = new PersistentData("jobsList.txt");

Map<String,dynamic> jobsInfo = new Map<String,dynamic>();

Map<String,Map<String,PersistentData>> jobsDataGetters = new Map<String,Map<String,PersistentData>>();

Map<String,dynamic> jobShiftData = new Map<String,dynamic>();

String appDirectory;

DateTime currentTime;

Timer timer;

bool isDeleting = false;

final dateFormat = DateFormat("EE, MMM d, yyyy");

final timeFormat = DateFormat("h:mm a");

void main() async{
  currentTime = new DateTime.now().toUtc();
  currentTime = currentTime.subtract(new Duration(seconds:currentTime.second,milliseconds:currentTime.millisecond,microseconds:currentTime.microsecond));
  appDirectory = (await getApplicationDocumentsDirectory()).path;
  jobsInfo = (await jobsInfoData.readData());
  if(jobsInfo==null){
    jobsInfo = new Map<String,dynamic>();
    jobsInfoData.writeData(jobsInfo);
  }
  int totalShifts = 0;
  for(String s in jobsInfo.keys){
    totalShifts+=jobsInfo[s]["scheduledShifts"];
  }
  int handledShifts = 0;
  if(jobsInfo.keys.length>0){
    jobsInfo.keys.forEach((s){
      Directory d = new Directory("$appDirectory/$s")..createSync(recursive: true);
      List l = d.listSync(recursive: true);
      if(l.length==0){
        jobsDataGetters[s] = new Map<String,PersistentData>();
        jobShiftData[s] = new Map<String,dynamic>();
        if(handledShifts==totalShifts){
          runApp(new App());
        }
      }else{
        l.forEach((f){
          List<String> pathToFile = f.path.split("/");
          String fileName = pathToFile[pathToFile.length-1].substring(0,pathToFile[pathToFile.length-1].lastIndexOf((".")));
          if(jobsDataGetters[s]==null){
            jobsDataGetters[s] = new Map<String,PersistentData>();
          }
          if(jobShiftData[s]==null){
            jobShiftData[s] = new Map<String,dynamic>();
          }
          jobsDataGetters[s][fileName] = new PersistentData("$s/$fileName.txt");
          jobsDataGetters[s][fileName].readData().then((r){
            jobShiftData[s][fileName] = r;
            if(++handledShifts==totalShifts){
              runApp(new App());
            }
          });
        });
      }
    });
  }else{
    runApp(new App());
  }
}

class App extends StatefulWidget{
  @override
  AppState createState() => new AppState();
}

class AppState extends State<App>{

  @override
  void initState(){
    super.initState();
    timer = new Timer.periodic(new Duration(seconds:2),(t){
      DateTime now = new DateTime.now().toUtc();
      if(now.minute!=currentTime.minute){
        setState((){
          currentTime = now.subtract(new Duration(seconds:now.second,milliseconds:now.millisecond,microseconds:now.microsecond));
        });
      }
    });
  }

  @override
  void dispose(){
    super.dispose();
    timer.cancel();
  }

  @override
  Widget build(BuildContext context){
    List jobs = jobsInfo.keys.toList();
    int jobsCount = jobs.length;
    return new MaterialApp(
      home: new Builder(
        builder: (context)=>new Scaffold(
          body:new Stack(
            children: [
              new CustomScrollView(
                  slivers: [
                    new SliverAppBar(
                        pinned: false,
                        floating: true,
                        title: new Text("Jobs"),
                        actions: [
                          new IconButton(
                              icon: new Icon(!isDeleting?Icons.delete:Icons.check),
                              onPressed: (){
                                setState((){
                                  isDeleting = !isDeleting;
                                });
                              }
                          )
                        ],
                        backgroundColor:new Color.fromRGBO(65,65,65,1.0)
                    ),
                    new SliverList(
                        delegate: new SliverChildBuilderDelegate((context,i)=>new Padding(padding:EdgeInsets.only(left:5.0,right:5.0,top:5.0),child:new Card(child:new Container(color:Colors.grey[300],child:new ListTile(title:new Text("New Job",style:new TextStyle(fontWeight: FontWeight.bold)),trailing:new IconButton(
                          icon: new Icon(Icons.add_circle_outline),
                          onPressed:(){
                            Navigator.push(context,new PageRouteBuilder(
                              pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation){
                                return new NewJobPage();
                              },
                              transitionDuration: new Duration(milliseconds: 150),
                              transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
                                return new FadeTransition(
                                    opacity: animation,
                                    child: child
                                );
                              },
                            ));
                          }
                        ),onTap:(){
                          Navigator.push(context,new PageRouteBuilder(
                            pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation){
                              return new NewJobPage();
                            },
                            transitionDuration: new Duration(milliseconds: 150),
                            transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
                              return new FadeTransition(
                                  opacity: animation,
                                  child: child
                              );
                            },
                          ));
                        })))),childCount:1)
                    ),
                    new SliverPadding(
                        sliver: new SliverStaggeredGrid.countBuilder(
                          crossAxisCount: (MediaQuery.of(context).size.width/500.0).ceil(),
                          mainAxisSpacing: 0.0,
                          crossAxisSpacing: 0.0,
                          itemCount:jobsCount,
                          itemBuilder: (BuildContext context, int i)=>new Job(jobs[i]),
                          staggeredTileBuilder:(i)=>new StaggeredTile.fit(1),
                        ),
                        padding:EdgeInsets.only(top:5.0,right:5.0,left:5.0,bottom:5.0)
                    )
                  ]
              ),
              new Container(
                height: MediaQuery.of(context).padding.top,
                width: double.infinity,
                color:new Color.fromRGBO(65,65,65,1.0)
              )
            ]
          )
        )
      ),
      debugShowCheckedModeBanner: false
    );
  }
}

class NewJobPage extends StatefulWidget{
  @override
  NewJobPageState createState() => new NewJobPageState();
}

class NewJobPageState extends State<NewJobPage>{

  bool clickedSubmit = false;

  Map<String,dynamic> inputData = new Map<String,dynamic>();

  @override
  Widget build(BuildContext context){
    return new Scaffold(
      appBar: new AppBar(title:new Text("New Job"),backgroundColor: new Color.fromRGBO(65,65,65,1.0)),
      body: new ListView(
        children: [
          new TextField(
            onChanged: (s){
              inputData["jobTitle"] = s;
            }
          ),
          new TextField(
            onChanged: (s){
              inputData["salary"] = double.parse(s);
            },
            inputFormatters: [new NumberInputFormatter()],
          ),
          new Builder(
            builder: (context)=>new RaisedButton(
                onPressed: () async{
                  if(clickedSubmit){
                    return;
                  }
                  if(inputData.keys.length<2||inputData.containsValue("")||inputData.containsValue(null)){
                    Scaffold.of(context).removeCurrentSnackBar();
                    Scaffold.of(context).showSnackBar(new SnackBar(duration: new Duration(milliseconds:750),content:new Text("Please complete all fields")));
                    return;
                  }
                  if(jobsInfo.keys.map((s)=>s.toUpperCase()).contains(inputData["jobTitle"].toUpperCase())){
                    Scaffold.of(context).removeCurrentSnackBar();
                    Scaffold.of(context).showSnackBar(new SnackBar(duration: new Duration(milliseconds:750),content:new Text("Job already exists")));
                    return;
                  }
                  clickedSubmit = true;
                  inputData["shiftsWorked"] = 0;
                  inputData["moneyEarned"] = 0.0;
                  inputData["minutesWorked"] = 0;
                  inputData["scheduledShifts"] = 0;
                  jobsInfo[inputData["jobTitle"]] = inputData;
                  new Directory("$appDirectory/${inputData["jobTitle"]}")..createSync(recursive: true);
                  jobShiftData[inputData["jobTitle"]] = new Map<String,dynamic>();
                  jobsDataGetters[inputData["jobTitle"]] = new Map<String,PersistentData>();
                  inputData.remove("jobTitle");
                  await jobsInfoData.writeData(jobsInfo);
                  context.ancestorStateOfType(new TypeMatcher<AppState>()).setState((){});
                  Navigator.of(context).pop();
                },
                child: new Text("Submit")
            )
          )
        ]
      )
    );
  }
}

class NewShiftPage extends StatefulWidget{
  final String jobTitle;
  NewShiftPage(this.jobTitle);
  @override
  NewShiftPageState createState() => new NewShiftPageState();
}

class NewShiftPageState extends State<NewShiftPage>{

  bool clickedSubmit = false;

  int startTime;

  int endTime;

  @override
  void initState(){
    super.initState();
    DateTime now = new DateTime.now();
    now = now.subtract(new Duration(seconds: now.second,milliseconds: now.millisecond,microseconds: now.microsecond));
    startTime = now.millisecondsSinceEpoch;
    endTime = now.add(new Duration(hours:4)).millisecondsSinceEpoch;
  }

  @override
  Widget build(BuildContext context){
    if(startTime<currentTime.millisecondsSinceEpoch){
      startTime = new DateTime.now().millisecondsSinceEpoch;
    }
    if(endTime<startTime){
      endTime = new DateTime(startTime).add(new Duration(hours:4)).millisecondsSinceEpoch;
    }
    return new Scaffold(
        appBar: new AppBar(title:new Text("New Shift"),backgroundColor: new Color.fromRGBO(65,65,65,1.0)),
        body: new Builder(
          builder: (context)=>new ListView(
              children: [
                new Container(height:16.0),
                new Center(
                  child: new Text("Shift Time",style: new TextStyle(fontSize:20.0,fontWeight: FontWeight.bold))
                ),
                new Container(height:5.0),
                new ListTile(
                    title: new Text(dateFormat.format(new DateTime.fromMillisecondsSinceEpoch(startTime))),
                    subtitle: new Text("Start Time"),
                    onTap:() async{
                      DateTime now = new DateTime.now();
                      now = new DateTime(now.year,now.month,now.day);
                      DateTime selectedDate = (await showDatePicker(
                          context: context,
                          initialDate: new DateTime.fromMillisecondsSinceEpoch(startTime),
                          firstDate: now,
                          lastDate: new DateTime(3000)
                      ));
                      if(selectedDate!=null){
                        selectedDate = new DateTime(selectedDate.year,selectedDate.month,selectedDate.day);
                        DateTime startDate = new DateTime.fromMillisecondsSinceEpoch(startTime);
                        startTime = selectedDate.millisecondsSinceEpoch + (startDate.hour*3600+startDate.minute*60+startDate.second)*1000;
                        if(endTime<startTime){
                          endTime = new DateTime.fromMillisecondsSinceEpoch(startTime).add(new Duration(hours:4)).millisecondsSinceEpoch;
                        }
                        this.setState((){});
                      }
                    },
                    trailing: new OutlineButton(child: new Text(timeFormat.format(new DateTime.fromMillisecondsSinceEpoch(startTime))), onPressed: () async{
                      DateTime startDate = new DateTime.fromMillisecondsSinceEpoch(startTime);
                      DateTime endDate = new DateTime.fromMillisecondsSinceEpoch(endTime);
                      TimeOfDay selectedTime = await showTimePicker(
                          context: context,
                          initialTime: new TimeOfDay(hour:startDate.hour,minute:startDate.minute)
                      );
                      if(selectedTime!=null){
                        if(selectedTime.hour*60+selectedTime.minute>endDate.hour*60+endDate.minute){
                          Scaffold.of(context).removeCurrentSnackBar();
                          Scaffold.of(context).showSnackBar(new SnackBar(duration:new Duration(milliseconds: 750),content:new Text("Invalid time")));
                          return;
                        }
                        startTime = new DateTime(startDate.year,startDate.month,startDate.day,selectedTime.hour,selectedTime.minute).millisecondsSinceEpoch;
                        this.setState((){});
                      }
                    })
                ),
                new ListTile(
                    title: new Text(dateFormat.format(new DateTime.fromMillisecondsSinceEpoch(endTime))),
                    subtitle: new Text("End Time"),
                    onTap:() async{
                      DateTime min = new DateTime.fromMillisecondsSinceEpoch(startTime);
                      min = new DateTime(min.year,min.month,min.day);
                      DateTime selectedDate = (await showDatePicker(
                          context: context,
                          initialDate: new DateTime.fromMillisecondsSinceEpoch(endTime),
                          firstDate: min,
                          lastDate: new DateTime(3000)
                      ));
                      if(selectedDate!=null){
                        selectedDate = new DateTime(selectedDate.year,selectedDate.month,selectedDate.day);
                        DateTime endDate = new DateTime.fromMillisecondsSinceEpoch(endTime);
                        endTime = selectedDate.millisecondsSinceEpoch + (endDate.hour*3600+endDate.minute*60+endDate.second)*1000;
                        this.setState((){});
                      }
                    },
                    trailing: new OutlineButton(child: new Text(timeFormat.format(new DateTime.fromMillisecondsSinceEpoch(endTime))), onPressed: () async{
                      DateTime startDate = new DateTime.fromMillisecondsSinceEpoch(startTime);
                      DateTime endDate = new DateTime.fromMillisecondsSinceEpoch(endTime);
                      TimeOfDay selectedTime = await showTimePicker(
                          context: context,
                          initialTime: new TimeOfDay(hour:endDate.hour,minute:endDate.minute)
                      );
                      if(selectedTime!=null){
                        if(selectedTime.hour*60+selectedTime.minute<startDate.hour*60+startDate.minute){
                          Scaffold.of(context).removeCurrentSnackBar();
                          Scaffold.of(context).showSnackBar(new SnackBar(duration:new Duration(milliseconds: 750),content:new Text("Invalid time")));
                          return;
                        }
                        endTime = new DateTime(endDate.year,endDate.month,endDate.day,selectedTime.hour,selectedTime.minute).millisecondsSinceEpoch;
                        this.setState((){});
                      }
                    })
                ),
                new Builder(
                    builder: (context)=>new RaisedButton(
                        onPressed: () async{
                          if(clickedSubmit){
                            return;
                          }
                          clickedSubmit = true;
                          String shiftName = startTime.toString()+"-"+endTime.toString();
                          if(!jobShiftData[widget.jobTitle].keys.map((s)=>s.toUpperCase()).contains(shiftName.toUpperCase())){
                            jobShiftData[widget.jobTitle][shiftName] = {"startTime":startTime,"endTime":endTime};
                            jobsDataGetters[widget.jobTitle][shiftName] = new PersistentData("${widget.jobTitle}/${shiftName}.txt");
                            jobsDataGetters[widget.jobTitle][shiftName].writeData(jobShiftData[widget.jobTitle][shiftName]);
                            jobsInfo[widget.jobTitle]["scheduledShifts"]++;
                            jobsInfoData.writeData(jobsInfo);
                            this.setState((){});
                            Navigator.of(context).pop();
                          }else{
                            Scaffold.of(context).removeCurrentSnackBar();
                            Scaffold.of(context).showSnackBar(new SnackBar(duration:new Duration(milliseconds: 750),content:new Text("Duplicate shift")));
                            clickedSubmit = false;
                          }
                        },
                        child: new Text("Submit")
                    )
                )
              ]
          )
        )
    );
  }
}

class NumberInputFormatter extends TextInputFormatter{
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue){
    if((newValue.text.replaceAll(new RegExp("[^\.]"), "").length)>1){
      return oldValue;
    }
    return newValue.copyWith(text:newValue.text.replaceAll(new RegExp("[^0-9\.]"), ""));
  }
}

class DateTimeInputFormatter extends TextInputFormatter{
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue){
    bool isValid = false;
    try{
      dateFormat.parse(newValue.text);
    }catch(e){
      return oldValue;
    }
    return newValue;
  }
}


class Job extends StatefulWidget{
  final String jobTitle;
  Job(this.jobTitle);
  @override
  JobState createState()=>new JobState();
}

class JobState extends State<Job>{
  @override
  Widget build(BuildContext context){
    List shiftList = new List.from(jobShiftData[widget.jobTitle].keys.toList());
    shiftList.sort((o1,o2){
      int startDiff = (jobShiftData[widget.jobTitle][o1]["startTime"]-jobShiftData[widget.jobTitle][o2]["startTime"]);
      if(startDiff!=0){
        return startDiff;
      }else{
        return (jobShiftData[widget.jobTitle][o1]["endTime"]-jobShiftData[widget.jobTitle][o2]["endTime"]);
      }
    });
    int hoursWorked = (jobsInfo[widget.jobTitle]["minutesWorked"]/60).floor();
    int minutesWorked = (jobsInfo[widget.jobTitle]["minutesWorked"]%60);
    return new Center(
        child: new Card(
          child: new Column(
              children:[
                new ListTile(
                  onTap: (){
                    Navigator.push(context,new PageRouteBuilder(
                      pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation){
                        return new NewShiftPage(widget.jobTitle);
                      },
                      transitionDuration: new Duration(milliseconds: 150),
                      transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
                        return new FadeTransition(
                            opacity: animation,
                            child: child
                        );
                      },
                    ));
                  },
                  title: new Padding(padding:EdgeInsets.only(top:5.0),child:new Text(widget.jobTitle,style:new TextStyle(fontWeight: FontWeight.bold))),
                  subtitle: new Padding(padding:EdgeInsets.only(bottom:5.0),child:new Text("\$${new NumberFormat.compact().format(jobsInfo[widget.jobTitle]["salary"])}/hr • \$${new NumberFormat.compact().format(jobsInfo[widget.jobTitle]["moneyEarned"])} earned\n$hoursWorked hr${hoursWorked==1?"":"s"} $minutesWorked min${minutesWorked==1?"":"s"} worked")),
                  trailing: new IconButton(
                      icon: new Icon(!isDeleting?Icons.add_circle_outline:Icons.delete),
                      onPressed: (){
                        bool pressed = false;
                        if(isDeleting){
                          showDialog(
                              context: context,
                              barrierDismissible: true,
                              builder: (context){
                                return new AlertDialog(
                                    title:new Text("Are you sure?",style:new TextStyle(fontWeight:FontWeight.bold)),
                                    content:new Text("This job will be permanently deleted."),
                                    actions: [
                                      new FlatButton(
                                          child: new Text("No"),
                                          onPressed: (){
                                            if(pressed){
                                              return;
                                            }
                                            pressed = true;
                                            Navigator.of(context).pop();
                                          }
                                      ),
                                      new FlatButton(
                                          child: new Text("Yes"),
                                          onPressed: () async{
                                            if(pressed){
                                              return;
                                            }
                                            pressed = true;
                                            jobShiftData.remove(widget.jobTitle);
                                            jobsInfo.remove(widget.jobTitle);
                                            jobsDataGetters.remove(widget.jobTitle);
                                            jobsInfoData.writeData(jobsInfo);
                                            new Directory("$appDirectory/${widget.jobTitle}").delete(recursive: true);
                                            context.ancestorStateOfType(new TypeMatcher<AppState>()).setState((){});
                                            Navigator.of(context).pop();
                                          }
                                      )
                                    ]
                                );
                              }
                          );
                        }else{
                          Navigator.push(context,new PageRouteBuilder(
                            pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation){
                              return new NewShiftPage(widget.jobTitle);
                            },
                            transitionDuration: new Duration(milliseconds: 150),
                            transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
                              return new FadeTransition(
                                  opacity: animation,
                                  child: child
                              );
                            },
                          ));;
                        }
                      }
                  )
                ),
                shiftList.length>0?new Divider(height:4.0):new Container(),
                new Column(
                  children:shiftList.map((shiftTitle){
                    int startTime = jobShiftData[widget.jobTitle][shiftTitle]["startTime"];
                    int endTime = jobShiftData[widget.jobTitle][shiftTitle]["endTime"];
                    String startString = timeFormat.format(new DateTime.fromMillisecondsSinceEpoch(startTime));
                    String endString = timeFormat.format(new DateTime.fromMillisecondsSinceEpoch(endTime));
                    double percentDone = (currentTime.millisecondsSinceEpoch-startTime)/(endTime-startTime);
                    percentDone = max(0.0,min(percentDone,1.0));
                    int mins = new DateTime.fromMillisecondsSinceEpoch(max(startTime,min(endTime,currentTime.millisecondsSinceEpoch))).difference(new DateTime.fromMillisecondsSinceEpoch(startTime)).inMinutes;
                    return new ListTile(
                        title:new Text(startString+" - "+endString),
                        subtitle:new Row(
                            children: [
                              new Expanded(child:new Container(height:5.0,child:new LinearProgressIndicator(value:percentDone,valueColor: new AlwaysStoppedAnimation<Color>(percentDone==1.0?Colors.green:Colors.blue)))),
                              new Container(width:5.0),
                              new Container(height:16.0,width:40.0,child:new FittedBox(fit:BoxFit.fitHeight,alignment: Alignment.centerLeft,child:new Text((100*percentDone).floor().toStringAsFixed(0)+"%")))
                            ]
                        ),
                        onTap: percentDone==1.0?(){
                          int minutesWorked = new DateTime.fromMillisecondsSinceEpoch(endTime).difference(new DateTime.fromMillisecondsSinceEpoch(startTime)).inMinutes;
                          jobsInfo[widget.jobTitle]["minutesWorked"]+=minutesWorked;
                          jobsInfo[widget.jobTitle]["moneyEarned"]+=(jobsInfo[widget.jobTitle]["salary"]/60.0)*minutesWorked;
                          jobsInfo[widget.jobTitle]["moneyEarned"] = double.parse(jobsInfo[widget.jobTitle]["moneyEarned"].toStringAsFixed(2));
                          jobsInfo[widget.jobTitle]["scheduledShifts"]--;
                          jobsInfoData.writeData(jobsInfo);
                          jobShiftData[widget.jobTitle].remove(shiftTitle);
                          jobsDataGetters[widget.jobTitle].remove(shiftTitle);
                          new File("$appDirectory/${widget.jobTitle}/$shiftTitle.txt").delete(recursive: true);
                          this.setState((){});
                        }:null,
                        trailing:isDeleting?new IconButton(
                            icon:new Icon(Icons.delete),
                            onPressed:(){
                              int minutesWorked = new DateTime.fromMillisecondsSinceEpoch(max(startTime,min(endTime,currentTime.millisecondsSinceEpoch))).difference(new DateTime.fromMillisecondsSinceEpoch(startTime)).inMinutes;
                              if(minutesWorked>0){
                                showDialog(
                                    context: context,
                                    barrierDismissible: true,
                                    builder: (context){
                                      return new AlertDialog(
                                          title:new Text("Delete Shift",style:new TextStyle(fontWeight:FontWeight.bold)),
                                          content:new Text("Would you like to add the money you have earned so far to your savings?"),
                                          actions: [
                                            new FlatButton(
                                                child: new Text("No"),
                                                onPressed: (){
                                                  minutesWorked = new DateTime.fromMillisecondsSinceEpoch(max(startTime,min(endTime,currentTime.millisecondsSinceEpoch))).difference(new DateTime.fromMillisecondsSinceEpoch(startTime)).inMinutes;
                                                  jobShiftData[widget.jobTitle].remove(shiftTitle);
                                                  jobsDataGetters[widget.jobTitle].remove(shiftTitle);
                                                  jobsInfo[widget.jobTitle]["scheduledShifts"]--;
                                                  jobsInfoData.writeData(jobsInfo);
                                                  new File("$appDirectory/${widget.jobTitle}/$shiftTitle.txt").delete(recursive: true);
                                                  context.ancestorStateOfType(new TypeMatcher<AppState>()).setState((){});
                                                  Navigator.of(context).pop();
                                                }
                                            ),
                                            new FlatButton(
                                                child: new Text("Yes"),
                                                onPressed: () async{
                                                  minutesWorked = new DateTime.fromMillisecondsSinceEpoch(max(startTime,min(endTime,currentTime.millisecondsSinceEpoch))).difference(new DateTime.fromMillisecondsSinceEpoch(startTime)).inMinutes;
                                                  jobsInfo[widget.jobTitle]["minutesWorked"]+=minutesWorked;
                                                  jobsInfo[widget.jobTitle]["moneyEarned"]+=(jobsInfo[widget.jobTitle]["salary"]/60.0)*minutesWorked;
                                                  jobsInfo[widget.jobTitle]["moneyEarned"] = double.parse(jobsInfo[widget.jobTitle]["moneyEarned"].toStringAsFixed(2));
                                                  jobShiftData[widget.jobTitle].remove(shiftTitle);
                                                  jobsDataGetters[widget.jobTitle].remove(shiftTitle);
                                                  jobsInfo[widget.jobTitle]["scheduledShifts"]--;
                                                  jobsInfoData.writeData(jobsInfo);
                                                  new File("$appDirectory/${widget.jobTitle}/$shiftTitle.txt").delete(recursive: true);
                                                  context.ancestorStateOfType(new TypeMatcher<AppState>()).setState((){});
                                                  Navigator.of(context).pop();
                                                }
                                            )
                                          ]
                                      );
                                    }
                                );
                              }else{
                                jobShiftData[widget.jobTitle].remove(shiftTitle);
                                jobsDataGetters[widget.jobTitle].remove(shiftTitle);
                                jobsInfo[widget.jobTitle]["scheduledShifts"]--;
                                jobsInfoData.writeData(jobsInfo);
                                new File("$appDirectory/${widget.jobTitle}/$shiftTitle.txt").delete(recursive: true);
                                context.ancestorStateOfType(new TypeMatcher<AppState>()).setState((){});
                              }
                            }
                        ):percentDone==1.0?new IconButton(
                          icon: new Icon(Icons.check_circle_outline),
                          color: Colors.green,
                          onPressed: (){
                            int minutesWorked = new DateTime.fromMillisecondsSinceEpoch(endTime).difference(new DateTime.fromMillisecondsSinceEpoch(startTime)).inMinutes;
                            jobsInfo[widget.jobTitle]["minutesWorked"]+=minutesWorked;
                            jobsInfo[widget.jobTitle]["moneyEarned"]+=(jobsInfo[widget.jobTitle]["salary"]/60.0)*minutesWorked;
                            jobsInfo[widget.jobTitle]["moneyEarned"] = double.parse(jobsInfo[widget.jobTitle]["moneyEarned"].toStringAsFixed(2));
                            jobsInfo[widget.jobTitle]["scheduledShifts"]--;
                            jobsInfoData.writeData(jobsInfo);
                            jobShiftData[widget.jobTitle].remove(shiftTitle);
                            jobsDataGetters[widget.jobTitle].remove(shiftTitle);
                            new File("$appDirectory/${widget.jobTitle}/$shiftTitle.txt").delete(recursive: true);
                            this.setState((){});
                          }
                        ):new Container(height:17.0,width:48.0,child:new Center(child:new FittedBox(fit:BoxFit.fitHeight,alignment: Alignment.centerRight,child:new Text("\$"+new NumberFormat.compact().format(((jobsInfo[widget.jobTitle]["salary"]/60.0)*mins))))))
                    );
                  }).cast<Widget>().toList()
                )
              ]
          )
        )
    );
  }
}

class PersistentData{

  PersistentData(this.name);

  String name;

  Future<File> get _localFile async{
    return new File("$appDirectory/$name").create(recursive: true);
  }

  Future<dynamic> readData() async{
    try{
      File file = await _localFile;
      return json.decode(await file.readAsString());
    }catch(e){
      return null;
    }
  }

  Future<File> writeData(dynamic data) async{
    final file = await _localFile;
    return file.writeAsString(json.encode(data));
  }

}