import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'login.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance.ref();
  final _formKey = GlobalKey<FormState>();

  String _name = '';
  String _email = '';
  String _password = '';

  void _register() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      try {
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );
        // Save additional user info to Firebase Realtime Database
        await _database.child('users').child(userCredential.user!.uid).set({
          'name': _name,
          'email': _email,
          'password': _password,
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Registration successful!'),
        ));
        Navigator.push(context, MaterialPageRoute(builder: (context)=>LoginPage()));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Registration failed: $e'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register'),
      automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  border: Border.all(
                    color: Colors.blue, // Set the color of the border
                    width: 2.0,        // Set the width of the border
                  ),
                ),
                width: constraints.maxWidth > 600 ? 400 : double.infinity,
                padding: EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 20,),
                      CircleAvatar(
                        radius: 70,
                        backgroundImage: AssetImage('assets/images/logo.png'), // Correct usage
                      ),
                      SizedBox(height: 15,),
                      TextFormField(
                        decoration: InputDecoration(labelText: 'Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide(color: Colors.grey)
                        )
                        ),
                        onSaved: (value) => _name = value!,
                        validator: (value) => value!.isEmpty ? 'Please enter your name' : null,
                      ),SizedBox(height: 8,),
                      TextFormField(
                        decoration: InputDecoration(labelText: 'Email',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(10)),
                                borderSide: BorderSide(color: Colors.grey)
                            )
                        ),
                        onSaved: (value) => _email = value!,
                        validator: (value) => value!.isEmpty || !value.contains('@') ? 'Enter a valid email' : null,
                      ),SizedBox(height: 8,),
                      TextFormField(
                        decoration: InputDecoration(labelText: 'Password',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(10)),
                                borderSide: BorderSide(color: Colors.grey)
                            )
                        ),
                        obscureText: true,
                        onSaved: (value) => _password = value!,
                        validator: (value) => value!.length < 6 ? 'Password must be at least 6 characters' : null,
                      ),
                      SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.lightBlueAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                          child: TextButton(
                              onPressed: (){
                                _register();
                                },
                              child: Text("Register",style: TextStyle(color: Colors.black),)
                          )
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("If you already have registered click on"),
                          TextButton(onPressed: (){
                            Navigator.push(context, MaterialPageRoute(builder: (context)=>LoginPage()));
                          }, child: Text('Login'))
                        ],
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}