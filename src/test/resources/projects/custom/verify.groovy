def root = context.projectDir
assert new File(root, 'target/classes/org/ejemplo/comunidad/recursos/Application.class').isFile()
assert new File(root, 'target/comunidad-recursos-1.2.3-SNAPSHOT.jar').isFile()
assert new File(root, 'pom.xml').getText('UTF-8').contains('${oracle-database.version}')
assert new File(root, 'src/main/resources/application.properties').getText('UTF-8').contains('${PORT:9094}')
assert new File(root, 'src/main/resources/application-oracle.properties').getText('UTF-8').contains('${ORACLE_PASSWORD}')
assert new File(root, 'database/01_estructura.sql').isFile()
assert new File(root, 'mvnw.cmd').isFile()
assert new File(root, '.mvn/wrapper/maven-wrapper.properties').isFile()
assert new File(root, '.gitignore').isFile()
assert new File(root, 'postman/Servicio-Generado.postman_collection.json').isFile()
new File(root, 'src').eachFileRecurse { file ->
    if (file.isFile()) {
        def text = file.getText('UTF-8')
        assert !text.contains('cl.duoc.foromoderacion')
        assert !text.contains('${package}')
    }
}
return true
