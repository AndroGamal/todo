import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:todo/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TodoScreen(),
    );
  }
}

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _taskController = TextEditingController();
  List<Map<String, dynamic>> _tasks = [];
  int _limit = 15; // Number of tasks to fetch
  ScrollController scrollController = ScrollController();
  // Function to fetch tasks from Firestore with a limit
  DateTime lastcreate = DateTime(2024, 1, 1);

  Future<void> _fetchTasks() async {
    try {
      QuerySnapshot querySnapshot =
          await _firestore
              .collection('tasks')
              .orderBy('createdAt', descending: true)
              .where(
                Filter(
                  "createdAt",
                  isGreaterThan: Timestamp.fromDate(lastcreate),
                ),
              ) // Order by creation date
              .limit(_limit) // Apply the limit
              .get();
      bool isfrist = true;
      setState(() {
        _tasks.addAll(
          querySnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            if (isfrist) {
              lastcreate = data["createdAt"].toDate();
              isfrist = false;
            }
            data['id'] = doc.id; // Add document ID to the map
            return data;
          }).toList(),
        );
      });
    } catch (e) {
      print('Error fetching tasks: $e');
    }
  }

  // Function to add a new task to Firestore
  void _addTask(String taskTitle) async {
    if (taskTitle.isNotEmpty) {
      try {
        DocumentReference docRef = await _firestore.collection('tasks').add({
          'title': taskTitle,
          'isDone': false,
          'createdAt': Timestamp.now(),
        });

        // Update local list
        setState(() {
          _tasks.insert(0, {
            'id': docRef.id,
            'title': taskTitle,
            'isDone': false,
          });

          if (_tasks.length > _limit) {
            _tasks
                .removeLast(); // Remove the oldest task if the limit is exceeded
          }
        });

        _taskController.clear();
      } catch (e) {
        print('Error adding task: $e');
      }
    }
  }

  // Function to toggle the status of a task
  void _toggleTaskStatus(Map<String, dynamic> task) async {
    try {
      await _firestore.collection('tasks').doc(task['id']).update({
        'isDone': !task['isDone'],
      });

      // Update local list
      setState(() {
        task['isDone'] = !task['isDone'];
      });
    } catch (e) {
      print('Error toggling task status: $e');
    }
  }

  // Function to delete a task
  void _deleteTask(String taskId) async {
    try {
      await _firestore.collection('tasks').doc(taskId).delete();

      // Remove from local list
      setState(() {
        _tasks.removeWhere((task) => task['id'] == taskId);
      });
    } catch (e) {
      print('Error deleting task: $e');
    }
  }

  bool isLoading = false;
  @override
  void initState() {
    super.initState();
    _fetchTasks(); // Fetch tasks when the screen is initialized
    scrollController.addListener(() {
      if (scrollController.position.pixels ==
              scrollController.position.maxScrollExtent &&
          !isLoading) {
        setState(() {
          isLoading = true;
        });

        // Simulate a network call or any other async operation
        Future.delayed(Duration(milliseconds: 1), () {
          setState(() {
            isLoading = false;
          });
          // Add your logic here to load more data
          print('Reached the end of the scroll');
          _fetchTasks();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Todo App')),
      body:
          _tasks.isEmpty
              ? const Center(child: Text('No tasks yet!'))
              : ListView.builder(
                controller: scrollController,
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  final isDone = task['isDone'] ?? false;

                  return ListTile(
                    leading: Checkbox(
                      value: isDone,
                      onChanged: (value) {
                        _toggleTaskStatus(task);
                      },
                    ),
                    title: Text(
                      task['title'],
                      style: TextStyle(
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone ? Colors.grey : Colors.black,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        _deleteTask(task['id']);
                      },
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _taskController,
                      decoration: const InputDecoration(
                        labelText: 'Enter Task Title',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        _addTask(_taskController.text.trim());
                        Navigator.pop(context);
                      },
                      child: const Text('Add Task'),
                    ),
                  ],
                ),
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
