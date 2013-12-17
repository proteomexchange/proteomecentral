//package uk.ac.ebi.pride.utils;

import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.mime.HttpMultipartMode;
import org.apache.http.entity.mime.MultipartEntityBuilder;
import org.apache.http.entity.mime.content.FileBody;
import org.apache.http.impl.client.HttpClientBuilder;
import org.apache.http.util.EntityUtils;

import java.io.File;
import java.io.IOException;

/**
 * @author Florian Reisinger
 */
public class PxXmlValidator {

    public static String postFile(File file, String user, String pass) {
        String responseMessage = null; // server response if we don't run into errors
        try {
            // create the POST attributes
            MultipartEntityBuilder builder = MultipartEntityBuilder.create();
            builder.setMode(HttpMultipartMode.BROWSER_COMPATIBLE);
            builder.addPart("ProteomeXchangeXML", new FileBody(file));
            builder.addTextBody("PXPartner", user);
            builder.addTextBody("authentication", pass);
            builder.addTextBody("method",  "validateXML");
            builder.addTextBody("test",  "yes");
            builder.addTextBody("verbose",  "yes");

            // create the POST request
            HttpPost post = new HttpPost("http://proteomecentral.proteomexchange.org/beta/cgi/Dataset");
            post.setEntity(builder.build());

            // execute the POST request
            HttpClient client = HttpClientBuilder.create().build();
            HttpResponse response = client.execute(post);

            // retrieve and inspect the response
            HttpEntity entity = response.getEntity();
            responseMessage = EntityUtils.toString(entity);

            // check the response status code
            int statusCode = response.getStatusLine().getStatusCode();
            if (statusCode != 200) {
                System.out.println("Error " + statusCode + " from server: " + responseMessage);
            }
        } catch (IOException e) {
            System.err.println("ERROR executing command! " + e.getMessage());
            e.printStackTrace();
        }

        return responseMessage;
    }

    public static void main(String[] args){

        // main class for command line usage
        // expects 3 parameters:
        //    the PX XML to validate
        //    the user account name
        //    the password for the account

        if (args == null || args.length < 3) {
            System.out.println("Three arguments are needed: PX XML file name, user name and password!");
            System.exit(-1);
        }

        String fileName = args[0];
        if (fileName == null || fileName.isEmpty() || !fileName.endsWith(".xml")) {
            System.out.println("You need to provide a PX XML file name (ending in .xml).");
            System.exit(-1);
        }
        String user = args[1];
        if (user == null || user.isEmpty()) {
            System.out.println("You need to provide a user name.");
            System.exit(-1);
        }
        String pass = args[2];
        if (pass == null || pass.isEmpty()) {
            System.out.println("You need to provide a password for your user.");
            System.exit(-1);
        }

        File pxFile = new File(fileName);
        if (!pxFile.exists() || !pxFile.canRead()) {
            System.out.println("The specified file does not exist or cannot be read: " + fileName);
            System.exit(-1);
        }

        // seems we have a valid file (we should do more checks to make sure the file is actually a PX XML)

        String response = postFile(pxFile, user, pass);
        System.out.println("Server response: " + response);

    }

}
