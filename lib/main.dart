import "package:flutter/material.dart";
import "package:path_provider/path_provider.dart";
import "dart:convert";
import "dart:io";
import "dart:async";

PersistentData jobsInfoData = new PersistentData("jobsList.txt");

Map<String,dynamic> jobsInfo = new Map<String,dynamic>();

Map<String,Map<String,PersistentData>> jobsDataGetters = new Map<String,Map<String,PersistentData>>();

Map<String,dynamic> jobShiftData = new Map<String,dynamic>();

String appDirectory;

DateTime currentTime;

Timer timer;

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
    int jobsCount = jobsInfo.keys.length;
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
                    title: new Text("Jobs")
                ),
                new SliverList(
                  delegate: new SliverChildBuilderDelegate(
                      (context,i)=>new Job(jobs[i]),
                      childCount: jobsCount
                  ),
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
    return new Center(
        child: new Card(
          child: new Column(
              children:[
                new ListTile(
                  title: new Text(widget.jobTitle,style:new TextStyle(fontWeight: FontWeight.bold)),
                  trailing: new IconButton(
                      icon: new Icon(Icons.add_circle_outline),
                      onPressed: (){
                        String shiftName = "shiftOne";
                        if(jobShiftData[widget.jobTitle][shiftName]==null){
                          jobShiftData[widget.jobTitle][shiftName] = {"startTime":1,"endTime":100};
                          jobsDataGetters[widget.jobTitle][shiftName] = new PersistentData("${widget.jobTitle}/$shiftName.txt");
                          jobsDataGetters[widget.jobTitle][shiftName].writeData(jobShiftData[widget.jobTitle][shiftName]);
                          jobsInfo[widget.jobTitle]["scheduledShifts"]++;
                          jobsInfoData.writeData(jobsInfo);
                          this.setState((){});
                        }
                      }
                  )
                ),
                new Column(
                  children:jobShiftData[widget.jobTitle].keys.map((shiftTitle)=>new ListTile(
                    title:new Text(shiftTitle),
                    subtitle:new Text(jobShiftData[widget.jobTitle][shiftTitle]["startTime"].toString()+"-"+jobShiftData[widget.jobTitle][shiftTitle]["endTime"].toString())
                  )).cast<Widget>().toList()
                )
              ]
          ),
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

  dynamic readData() async{
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