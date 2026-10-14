import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';


class AboutTokiloScreen extends StatelessWidget {

  const AboutTokiloScreen({
    super.key,
  });



  Future<void> _openUrl(
      BuildContext context,
      String url,
      ) async {

    final Uri uri = Uri.parse(url);


    try {

      final bool result = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );


      if (!result && context.mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(
            content: Text(
              "Unable to open link",
            ),
          ),

        );

      }


    } catch(e) {

      if(context.mounted){

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(
            content: Text(
              "Error: $e",
            ),
          ),

        );

      }

    }

  }




  Widget _buildTile(
      BuildContext context,
      IconData icon,
      String title,
      String url,
      ) {


    return Container(

      margin:
      const EdgeInsets.only(bottom:12),


      decoration: BoxDecoration(

        color:
        AppColors.surface,

        borderRadius:
        BorderRadius.circular(16),

        border:
        Border.all(
          color: AppColors.border,
        ),

      ),


      child: ListTile(

        onTap: (){

          _openUrl(
            context,
            url,
          );

        },


        leading: Container(

          width:45,

          height:45,


          decoration: BoxDecoration(

            color:
            AppColors.primary.withOpacity(0.1),

            borderRadius:
            BorderRadius.circular(14),

          ),


          child:
          Icon(

            icon,

            color:
            AppColors.primary,

          ),

        ),



        title: Text(

          title,

          style:
          const TextStyle(

            fontSize:16,

            fontWeight:
            FontWeight.w600,

          ),

        ),



        trailing:
        const Icon(

          Icons.arrow_forward_ios_rounded,

          size:16,

        ),


      ),

    );

  }





  @override
  Widget build(BuildContext context) {


    return Scaffold(


      backgroundColor:
      AppColors.background,



      appBar:
      AppBar(

        title:
        const Text(
          "About Tokilo",
        ),

        backgroundColor:
        AppColors.surface,

      ),





      body:
      ListView(

        padding:
        const EdgeInsets.all(20),


        children:[



          Container(

            padding:
            const EdgeInsets.all(24),


            decoration:
            BoxDecoration(

              gradient:
              AppColors.primaryGradient,


              borderRadius:
              BorderRadius.circular(24),


            ),



            child:
            Column(

              children:[



                Container(

                  width:80,

                  height:80,


                  padding:
                  const EdgeInsets.all(12),


                  decoration:
                  BoxDecoration(

                    color:
                    Colors.white,

                    borderRadius:
                    BorderRadius.circular(20),

                  ),


                  child:
                  Image.asset(
                    'assets/icons/tokilologo.png',
                  ),


                ),




                const SizedBox(height:18),




                const Text(

                  "Tokilo Business Hub",

                  style:
                  TextStyle(

                    color:
                    Colors.white,

                    fontSize:22,

                    fontWeight:
                    FontWeight.bold,

                  ),

                ),





                const SizedBox(height:8),




                Text(

                  "Your Complete Business Ecosystem",

                  style:

                  TextStyle(

                    color:
                    Colors.white70,

                    fontSize:14,

                  ),

                ),


              ],

            ),


          ),





          const SizedBox(height:25),




          _buildTile(

            context,

            Icons.language_rounded,

            "Tokilo Website",

            "https://tokilotech.com",

          ),




          _buildTile(

            context,

            Icons.privacy_tip_outlined,

            "Privacy Policy",

            "https://tokilotech.com/privacy-policy",

          ),




          _buildTile(

            context,

            Icons.description_outlined,

            "Terms & Conditions",

            "https://tokilotech.com/terms-and-conditions",

          ),




          _buildTile(

            context,

            Icons.email_outlined,

            "Contact Tokilo",

            "https://tokilotech.com/contact",

          ),





          const SizedBox(height:30),




          const Center(

            child:

            Text(

              "Tokilo Technologies\nVersion 1.0.0",

              textAlign:
              TextAlign.center,


              style:

              TextStyle(

                color:
                AppColors.textSecondary,

                fontSize:13,

              ),

            ),

          ),



        ],


      ),


    );


  }


}