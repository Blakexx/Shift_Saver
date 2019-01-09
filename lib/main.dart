import "package:flutter/material.dart";
import "package:path_provider/path_provider.dart";
import "dart:convert";
import "dart:io";
import "dart:async";
import "dart:math";
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';

PersistentData jobsInfoData = new PersistentData("jobsList.txt");

Map<String,dynamic> jobsInfo = new Map<String,dynamic>();

Map<String,Map<String,PersistentData>> jobsDataGetters = new Map<String,Map<String,PersistentData>>();

Map<String,dynamic> jobShiftData = new Map<String,dynamic>();

String appDirectory;

DateTime currentTime;

Timer timer;

bool isDeleting = false;

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
    timer = new Timer.periodic(new Duration(seconds:5),(t){
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
          floatingActionButton: new FloatingActionButton(
              onPressed: (){
                Navigator.push(context,new MaterialPageRoute(builder:(context)=>new NewJobPage()));
              },
              child: new Icon(Icons.add)
          ),
          body: new CustomScrollView(
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
                    ]
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
                  padding:EdgeInsets.only(top:5.0,right:5.0,left:5.0)
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

  @override
  void initState(){
    super.initState();

  }

  Map<String,dynamic> inputData = new Map<String,dynamic>();

  @override
  Widget build(BuildContext context){
    return new Scaffold(
      appBar: new AppBar(title:new Text("New Job")),
      body: new ListView(
        children: [
          new TextField(
            onChanged: (s){
              inputData["jobTitle"] = s;
            },
          ),
          new RaisedButton(
            onPressed: () async{
              if(clickedSubmit){
                return;
              }
              if(inputData.keys.length<1||inputData.containsValue("")||inputData.containsValue(null)){
                return;
              }
              if(jobsInfo.keys.map((s)=>s.toUpperCase()).contains(inputData["jobTitle"].toUpperCase())){
                return;
              }
              clickedSubmit = true;
              inputData["shiftsWorked"] = 0;
              inputData["moneyEarned"] = 0.0;
              inputData["minutesWorked"] = 0;
              inputData["scheduledShifts"] = 0;
              inputData["salary"] = 0.0;
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
        ]
      )
    );
  }
}

class Job extends StatefulWidget{
  String jobTitle;
  Job(this.jobTitle);
  @override
  JobState createState()=>new JobState();
}

class JobState extends State<Job>{
  @override
  Widget build(BuildContext context){
    List shiftList = new List.from(jobShiftData[widget.jobTitle].keys.toList());
    shiftList.sort((o1,o2)=>(jobShiftData[widget.jobTitle][o2]["startTime"]-jobShiftData[widget.jobTitle][o1]["startTime"]) as int);
    return new Center(
        child: new Card(
          child: new Column(
              children:[
                new ListTile(
                  leading: isDeleting?new IconButton(
                    icon:new Icon(Icons.delete),
                    onPressed:(){
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
                                        Navigator.of(context).pop();
                                      }
                                  ),
                                  new FlatButton(
                                      child: new Text("Yes"),
                                      onPressed: () async{
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
                    }
                  ):null,
                  title: new Text(widget.jobTitle,style:new TextStyle(fontWeight: FontWeight.bold)),
                  trailing: new IconButton(
                      icon: new Icon(Icons.add_circle_outline),
                      onPressed: (){
                        int startTime = currentTime.toUtc().millisecondsSinceEpoch;
                        int endTime = (currentTime.toUtc().millisecondsSinceEpoch+1000*60*2);
                        String shiftName = startTime.toString()+"-"+endTime.toString();
                        bool pressed = false;
                        showDialog(
                            context: context,
                            barrierDismissible: true,
                            builder: (context){
                              return new AlertDialog(
                                  title: new Text("New Shift",style:new TextStyle(fontWeight:FontWeight.bold)),
                                  content: new TextField(
                                    onChanged:(st){

                                    },
                                    decoration: new InputDecoration(
                                      hintText: "Start Time"
                                    ),
                                  ),
                                  actions: [
                                    new FlatButton(
                                        child: new Text("Submit"),
                                        onPressed: () async{
                                          if(pressed){
                                            return;
                                          }
                                          pressed = true;
                                          if(!jobShiftData[widget.jobTitle].keys.map((s)=>s.toUpperCase()).contains(shiftName.toUpperCase())){
                                            jobShiftData[widget.jobTitle][shiftName] = {"startTime":startTime,"endTime":endTime};
                                            jobsDataGetters[widget.jobTitle][shiftName] = new PersistentData("${widget.jobTitle}/${shiftName}.txt");
                                            jobsDataGetters[widget.jobTitle][shiftName].writeData(jobShiftData[widget.jobTitle][shiftName]);
                                            jobsInfo[widget.jobTitle]["scheduledShifts"]++;
                                            jobsInfoData.writeData(jobsInfo);
                                            this.setState((){});
                                            Navigator.of(context).pop();
                                          }else{
                                            pressed = false;
                                          }
                                        }
                                    )
                                  ]
                              );
                            }
                        );
                      }
                  )
                ),
                shiftList.length>0?new Divider(height:4.0):new Container(),
                new Column(
                  children:shiftList.map((shiftTitle){
                    int startTime = jobShiftData[widget.jobTitle][shiftTitle]["startTime"];
                    int endTime = jobShiftData[widget.jobTitle][shiftTitle]["endTime"];
                    String startString = getHourMin(startTime);
                    String endString = getHourMin(endTime);
                    double percentDone = (currentTime.millisecondsSinceEpoch-startTime)/(endTime-startTime);
                    percentDone = max(0.0,min(percentDone,1.0));
                    return new ListTile(
                        leading: isDeleting?new IconButton(
                            icon:new Icon(Icons.delete),
                            onPressed:(){
                              int minutesWorked = new DateTime.fromMillisecondsSinceEpoch(max(startTime,min(endTime,currentTime.millisecondsSinceEpoch))).difference(new DateTime.fromMillisecondsSinceEpoch(startTime)).inMinutes;
                              if(minutesWorked>0){
                                showDialog(
                                    context: context,
                                    barrierDismissible: true,
                                    builder: (context){
                                      return new AlertDialog(
                                          title:new Text("Cancel Shift",style:new TextStyle(fontWeight:FontWeight.bold)),
                                          content:new Text("Would you like to add the money you have earned so far to your savings?"),
                                          actions: [
                                            new FlatButton(
                                                child: new Text("No"),
                                                onPressed: (){
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
                                                  jobsInfo[widget.jobTitle]["minutesWorked"]+=minutesWorked;
                                                  jobsInfo[widget.jobTitle]["moneyEarned"]+=(jobsInfo[widget.jobTitle]["salary"]/60.0)*minutesWorked;
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
                        ):null,
                        title:new Text(startString+" - "+endString),
                        subtitle:new Row(
                            children: [
                              new Expanded(child:new Container(height:5.0,child:new LinearProgressIndicator(value:percentDone,valueColor: new AlwaysStoppedAnimation<Color>(percentDone==1.0?Colors.green:Colors.blue)))),
                              new Container(height:16.0,width:40.0,child:new FittedBox(fit:BoxFit.fitHeight,alignment: Alignment.centerRight,child:new Text((100*percentDone).floor().toStringAsFixed(0)+"%")))
                            ]
                        ),
                        trailing: percentDone==1.0?new IconButton(
                          icon: new Icon(Icons.check_circle_outline),
                          color: Colors.green,
                          onPressed: (){
                            int minutesWorked = new DateTime.fromMillisecondsSinceEpoch(endTime).difference(new DateTime.fromMillisecondsSinceEpoch(startTime)).inMinutes;
                            jobsInfo[widget.jobTitle]["minutesWorked"]+=minutesWorked;
                            jobsInfo[widget.jobTitle]["moneyEarned"]+=(jobsInfo[widget.jobTitle]["salary"]/60.0)*minutesWorked;
                            jobsInfo[widget.jobTitle]["scheduledShifts"]--;
                            jobsInfoData.writeData(jobsInfo);
                            jobShiftData[widget.jobTitle].remove(shiftTitle);
                            jobsDataGetters[widget.jobTitle].remove(shiftTitle);
                            new File("$appDirectory/${widget.jobTitle}/$shiftTitle.txt").delete(recursive: true);
                            this.setState((){});
                          }
                        ):null
                    );
                  }).cast<Widget>().toList()
                )
              ]
          )
        )
    );
  }
}

String getHourMin(int mill){
  NumberFormat twoDigits = new NumberFormat("00", "en_US");
  DateTime time = new DateTime.fromMillisecondsSinceEpoch(mill);
  return twoDigits.format(time.hour%12==0?12:time.hour%12)+":"+twoDigits.format(time.minute)+" ${time.hour>=12?"PM":"AM"}";
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